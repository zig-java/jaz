const std = @import("std");

const Heap = @import("Heap.zig");
const array = @import("array.zig");
const utils = @import("utils.zig");
const Object = @import("Object.zig");
const StaticPool = @import("StaticPool.zig");
const StackFrame = @import("StackFrame.zig");
const primitives = @import("primitives.zig");
const ClassResolver = @import("ClassResolver.zig");

const cf = @import("cf");

const opcodes = cf.bytecode.ops;
const MethodInfo = cf.MethodInfo;
const ClassFile = cf.ClassFile;
const attributes = cf.attributes;
const descriptors = cf.descriptors;
const ConstantPool = cf.ConstantPool;

const Interpreter = @This();

allocator: std.mem.Allocator,
heap: Heap,
static_pool: StaticPool,
class_resolver: *ClassResolver,

pub fn init(allocator: std.mem.Allocator, class_resolver: *ClassResolver) Interpreter {
    return .{ .allocator = allocator, .heap = Heap.init(allocator), .static_pool = StaticPool.init(allocator), .class_resolver = class_resolver };
}

pub fn call(self: *Interpreter, path: []const u8, args: anytype) !primitives.PrimitiveValue {
    var class_file = (try self.class_resolver.resolve(path[0..std.mem.lastIndexOf(u8, path, "/").?])).?;
    var method_name = path[std.mem.lastIndexOf(u8, path, "/").? + 1 ..];
    var margs: [std.meta.fields(@TypeOf(args)).len]primitives.PrimitiveValue = undefined;

    var method_info: ?MethodInfo = null;
    for (class_file.methods.items) |*m| {
        if (!std.mem.eql(u8, m.getName().bytes, method_name)) continue;

        method_info = m.*;
    }

    inline for (std.meta.fields(@TypeOf(args))) |field, i| {
        margs[i] = primitives.PrimitiveValue.fromNative(@field(args, field.name));
    }

    return self.interpret(class_file, method_name, &margs);
}

fn useStaticClass(self: *Interpreter, class_name: []const u8) !void {
    if (!self.static_pool.hasClass(class_name)) {
        var clname = try std.mem.concat(self.allocator, u8, &.{ class_name, ".<clinit>" });
        defer self.allocator.free(clname);

        _ = try self.static_pool.addClass(class_name, (try self.class_resolver.resolve(class_name)).?);

        _ = self.call(clname, .{}) catch |err| switch (err) {
            error.ClassNotFound => @panic("Big problem!!!"),
            error.MethodNotFound => {},
            else => unreachable,
        };
    }
}

pub fn newObject(self: *Interpreter, class_name: []const u8) !primitives.reference {
    return try self.heap.newObject((try self.class_resolver.resolve(class_name)).?, self.class_resolver);
}

pub fn new(self: *Interpreter, class_name: []const u8, args: anytype) !primitives.reference {
    var inits = try std.mem.concat(self.allocator, u8, &.{ class_name, ".<init>" });
    defer self.allocator.free(inits);

    var object = try self.newObject(class_name);
    _ = try self.call(inits, .{object} ++ args);
    return object;
}

pub fn findMethod(self: *Interpreter, class_file: *const ClassFile, method_name: []const u8, args: []primitives.PrimitiveValue) !?*const MethodInfo {
    method_search: for (class_file.methods.items) |*method| {
        if (!std.mem.eql(u8, method.getName().bytes, method_name)) continue;
        var method_descriptor_str = method.getDescriptor().bytes;
        var method_descriptor = try descriptors.parseString(self.allocator, method_descriptor_str);

        if (method_descriptor.method.parameters.len != args.len - if (method.access_flags.static) @as(usize, 0) else @as(usize, 1)) continue;

        var tindex: usize = 0;
        var toffset = if (method.access_flags.static) @as(usize, 0) else @as(usize, 1);

        while (tindex < method_descriptor.method.parameters.len) : (tindex += 1) {
            var param = method_descriptor.method.parameters[tindex];
            switch (param.*) {
                .int => if (args[tindex + toffset] != .int) continue :method_search,
                .object => |o| {
                    if (args[tindex + toffset].isNull()) continue :method_search;
                    switch (self.heap.get(args[tindex + toffset].reference).*) {
                        .object => |o2| {
                            var cn = try o2.getClassName();
                            defer self.allocator.free(cn);
                            if (!std.mem.eql(u8, o, cn)) {
                                continue :method_search;
                            }
                        },
                        else => continue :method_search,
                    }
                },
                .array => |a| {
                    switch (self.heap.get(args[tindex + toffset].reference).*) {
                        .array => |a2| {
                            // if (a2.)
                            switch (a2) {
                                .byte => if (a.* != .byte) continue :method_search,
                                else => continue :method_search,
                            }
                        },
                        else => continue :method_search,
                    }
                },
                else => unreachable,
            }
        }

        return method;
    }

    return null;
}

fn interpret(self: *Interpreter, class_file: *const ClassFile, method_name: []const u8, args: []primitives.PrimitiveValue) anyerror!primitives.PrimitiveValue {
    var descriptor_buf = std.ArrayList(u8).init(self.allocator);
    defer descriptor_buf.deinit();

    var method = (try self.findMethod(class_file, method_name, args)) orelse return error.MethodNotFound;

    descriptor_buf.shrinkRetainingCapacity(0);
    try utils.formatMethod(self.allocator, class_file, method, descriptor_buf.writer());
    std.log.info("{d} {d}", .{ @ptrToInt(class_file.constant_pool), @ptrToInt(class_file.constant_pool.get(class_file.this_class).class.constant_pool) });
    std.log.info("method: {s} {s}", .{ class_file.constant_pool.get(class_file.this_class).class.getName().bytes, descriptor_buf.items });

    // TODO: See descriptors.zig
    for (method.attributes.items) |*att| {
        // var data = try att.readData(self.allocator, class_file);
        std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{@tagName(att.*)});

        switch (att.*) {
            .code => |code_attribute| {
                var stack_frame = StackFrame.init(self.allocator, class_file);
                defer stack_frame.deinit();

                try stack_frame.local_variables.appendSlice(args);

                var fbs = std.io.fixedBufferStream(code_attribute.code.items);
                var fbs_reader = fbs.reader();

                var opcode = try opcodes.Operation.decode(self.allocator, fbs_reader);

                while (true) {
                    std.log.info((" " ** 8) ++ "{any}", .{opcode});

                    // TODO: Rearrange everything according to https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html
                    switch (opcode) {
                        // Constants
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Constants" for order
                        .nop => {},
                        .aconst_null => try stack_frame.operand_stack.push(.{ .reference = 0 }),

                        .iconst_m1 => try stack_frame.operand_stack.push(.{ .int = -1 }),
                        .iconst_0 => try stack_frame.operand_stack.push(.{ .int = 0 }),
                        .iconst_1 => try stack_frame.operand_stack.push(.{ .int = 1 }),
                        .iconst_2 => try stack_frame.operand_stack.push(.{ .int = 2 }),
                        .iconst_3 => try stack_frame.operand_stack.push(.{ .int = 3 }),
                        .iconst_4 => try stack_frame.operand_stack.push(.{ .int = 4 }),
                        .iconst_5 => try stack_frame.operand_stack.push(.{ .int = 5 }),

                        .lconst_0 => try stack_frame.operand_stack.push(.{ .long = 0 }),
                        .lconst_1 => try stack_frame.operand_stack.push(.{ .long = 1 }),

                        .fconst_0 => try stack_frame.operand_stack.push(.{ .float = 0 }),
                        .fconst_1 => try stack_frame.operand_stack.push(.{ .float = 1 }),
                        .fconst_2 => try stack_frame.operand_stack.push(.{ .float = 2 }),

                        .dconst_0 => try stack_frame.operand_stack.push(.{ .double = 0 }),
                        .dconst_1 => try stack_frame.operand_stack.push(.{ .double = 1 }),

                        .bipush => |value| try stack_frame.operand_stack.push(.{ .int = value }),
                        .sipush => |value| try stack_frame.operand_stack.push(.{ .int = value }),

                        .ldc => |index| {
                            switch (stack_frame.class_file.constant_pool.get(index)) {
                                .integer => |f| try stack_frame.operand_stack.push(.{ .int = @bitCast(primitives.int, f.bytes) }),
                                .float => |f| try stack_frame.operand_stack.push(.{ .float = @bitCast(primitives.float, f.bytes) }),
                                .string => |s| {
                                    var utf8 = class_file.constant_pool.get(s.string_index).utf8;
                                    var ref = try self.heap.newArray(.byte, @intCast(primitives.int, utf8.bytes.len));
                                    var arr = self.heap.getArray(ref);

                                    std.mem.copy(i8, arr.byte.slice, @ptrCast([*]const i8, utf8.bytes.ptr)[0..utf8.bytes.len]);

                                    try stack_frame.operand_stack.push(.{ .reference = try self.new("java.lang.String", .{ref}) });
                                },
                                .class => |class| {
                                    var class_name_slashes = class.getName().bytes;
                                    var class_name = class_name_slashes;
                                    defer self.allocator.free(class_name);

                                    try stack_frame.operand_stack.push(.{ .reference = try self.heap.newObject((try self.class_resolver.resolve(class_name)).?, self.class_resolver) });
                                },
                                else => {
                                    std.log.info("{any}", .{stack_frame.class_file.constant_pool.get(index)});
                                    unreachable;
                                },
                            }
                        },
                        .ldc_w => |index| {
                            switch (stack_frame.class_file.constant_pool.get(index)) {
                                .integer => |f| try stack_frame.operand_stack.push(.{ .int = @bitCast(primitives.int, f.bytes) }),
                                .float => |f| try stack_frame.operand_stack.push(.{ .float = @bitCast(primitives.float, f.bytes) }),
                                .string => |s| {
                                    var utf8 = class_file.constant_pool.get(s.string_index).utf8;
                                    var ref = try self.heap.newArray(.byte, @intCast(primitives.int, utf8.bytes.len));
                                    var arr = self.heap.getArray(ref);

                                    std.mem.copy(i8, arr.byte.slice, @ptrCast([*]const i8, utf8.bytes.ptr)[0..utf8.bytes.len]);

                                    try stack_frame.operand_stack.push(.{ .reference = try self.new("java.lang.String", .{ref}) });
                                },
                                else => {
                                    std.log.info("{any}", .{stack_frame.class_file.constant_pool.get(index)});
                                    unreachable;
                                },
                            }
                        },
                        .ldc2_w => |index| {
                            switch (stack_frame.class_file.constant_pool.get(index)) {
                                .double => |d| try stack_frame.operand_stack.push(.{ .double = @bitCast(primitives.double, d.bytes) }),
                                .long => |l| try stack_frame.operand_stack.push(.{ .long = @bitCast(primitives.long, l.bytes) }),
                                else => unreachable,
                            }
                        },

                        // Loads
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Loads" for order

                        .iinc => |iinc| stack_frame.local_variables.items[iinc.index].int += iinc.@"const",

                        // zig fmt: off
                        inline
                        .iload, .iload_0, .iload_1, .iload_2, .iload_3,
                        .fload, .fload_0, .fload_1, .fload_2, .fload_3,
                        .dload, .dload_0, .dload_1, .dload_2, .dload_3,
                        .aload, .aload_0, .aload_1, .aload_2, .aload_3,
                        // zig fmt: on
                        => |body_index, current| {
                            const kind = comptime primitives.PrimitiveValueKind.fromSingleCharRepr(@tagName(current)[0]);
                            const index = comptime if (@tagName(current).len < 6) body_index else std.fmt.parseInt(usize, @tagName(current)[6..], 10) catch unreachable;

                            try stack_frame.operand_stack.push(@unionInit(
                                primitives.PrimitiveValue,
                                @tagName(kind),
                                @field(
                                    stack_frame.local_variables.items[index],
                                    @tagName(kind),
                                ),
                            ));
                        },

                        // zig fmt: off
                        inline
                        .istore, .istore_0, .istore_1, .istore_2, .istore_3,
                        .fstore, .fstore_0, .fstore_1, .fstore_2, .fstore_3,
                        .dstore, .dstore_0, .dstore_1, .dstore_2, .dstore_3,
                        .astore, .astore_0, .astore_1, .astore_2, .astore_3,
                        // zig fmt: on
                        => |body_index, current| {
                            const kind = comptime primitives.PrimitiveValueKind.fromSingleCharRepr(@tagName(current)[0]);
                            const index = comptime if (@tagName(current).len < 7) body_index else std.fmt.parseInt(usize, @tagName(current)[7..], 10) catch unreachable;

                            try stack_frame.setLocalVariable(index, @unionInit(
                                primitives.PrimitiveValue,
                                @tagName(kind),
                                @field(
                                    stack_frame.operand_stack.pop(),
                                    @tagName(kind),
                                ),
                            ));
                        },

                        .iadd => try stack_frame.operand_stack.push(.{ .int = stack_frame.operand_stack.pop().int + stack_frame.operand_stack.pop().int }),
                        .imul => try stack_frame.operand_stack.push(.{ .int = stack_frame.operand_stack.pop().int * stack_frame.operand_stack.pop().int }),
                        .isub => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { a: primitives.int, b: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = stackvals.a - stackvals.b });
                        },
                        .idiv => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.int, denominator: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = @divTrunc(stackvals.numerator, stackvals.denominator) });
                        },
                        // bitwise ops
                        .iand => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.int, denominator: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = stackvals.numerator & stackvals.denominator });
                        },
                        .ior => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.int, denominator: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = stackvals.numerator | stackvals.denominator });
                        },
                        .ixor => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.int, denominator: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = stackvals.numerator ^ stackvals.denominator });
                        },
                        .iushr => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.int, denominator: primitives.int });
                            try stack_frame.operand_stack.push(.{ .int = stackvals.numerator >> @intCast(std.math.Log2Int(primitives.int), stackvals.denominator) });
                        },

                        .fadd => try stack_frame.operand_stack.push(.{ .float = stack_frame.operand_stack.pop().float + stack_frame.operand_stack.pop().float }),
                        .fmul => try stack_frame.operand_stack.push(.{ .float = stack_frame.operand_stack.pop().float * stack_frame.operand_stack.pop().float }),
                        .fsub => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { a: primitives.float, b: primitives.float });
                            try stack_frame.operand_stack.push(.{ .float = stackvals.a - stackvals.b });
                        },
                        .fdiv => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.float, denominator: primitives.float });
                            try stack_frame.operand_stack.push(.{ .float = stackvals.numerator / stackvals.denominator });
                        },

                        .dadd => try stack_frame.operand_stack.push(.{ .double = stack_frame.operand_stack.pop().double + stack_frame.operand_stack.pop().double }),
                        .dmul => try stack_frame.operand_stack.push(.{ .double = stack_frame.operand_stack.pop().double * stack_frame.operand_stack.pop().double }),
                        .dsub => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { a: primitives.double, b: primitives.double });
                            try stack_frame.operand_stack.push(.{ .double = stackvals.a - stackvals.b });
                        },
                        .ddiv => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { numerator: primitives.double, denominator: primitives.double });
                            try stack_frame.operand_stack.push(.{ .double = stackvals.numerator / stackvals.denominator });
                        },

                        // Conditionals / jumps
                        // TODO: Implement all conditions (int comparison, 0 comparison, etc.)
                        .goto => |offset| {
                            try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                        },

                        // Stack
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Stack" for order
                        .pop => _ = stack_frame.operand_stack.pop(),
                        .pop2 => {
                            var first = stack_frame.operand_stack.pop();
                            if (first != .double and first != .long)
                                _ = stack_frame.operand_stack.pop();
                        },
                        .dup => try stack_frame.operand_stack.push(stack_frame.operand_stack.array_list.items[stack_frame.operand_stack.array_list.items.len - 1]),
                        // TODO: Implement the rest of the dupe squad
                        .swap => {
                            var first = stack_frame.operand_stack.pop();
                            var second = stack_frame.operand_stack.pop();

                            std.debug.assert(first != .double and
                                first != .long and
                                second != .double and
                                second != .long);

                            try stack_frame.operand_stack.push(first);
                            try stack_frame.operand_stack.push(second);
                        },

                        // Conversions
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Conversions"
                        inline .i2l, .i2f, .i2d, .l2i, .l2f, .l2d, .f2i, .f2l, .f2d, .d2i, .d2l, .d2f, .i2b, .i2c, .i2s => |_, current| {
                            const from = primitives.PrimitiveValueKind.fromSingleCharRepr(comptime @tagName(current)[0]);
                            const to = primitives.PrimitiveValueKind.fromSingleCharRepr(comptime @tagName(current)[2]);

                            const popped = stack_frame.operand_stack.pop();
                            std.debug.assert(popped == from);
                            try stack_frame.operand_stack.push(popped.cast(to));
                        },

                        // Java bad
                        .newarray => |atype| {
                            inline for (std.meta.fields(@TypeOf(atype))) |field| {
                                if (atype == @intToEnum(@TypeOf(atype), field.value))
                                    try stack_frame.operand_stack.push(.{ .reference = try self.heap.newArray(std.meta.stringToEnum(array.ArrayKind, field.name).?, stack_frame.operand_stack.pop().int) });
                            }
                        },
                        .anewarray => {
                            try stack_frame.operand_stack.push(.{ .reference = try self.heap.newArray(.reference, stack_frame.operand_stack.pop().int) });
                        },
                        .new => |index| {
                            var class_name_slashes = class_file.constant_pool.get(index).class.getName().bytes;
                            var class_name = class_name_slashes;
                            defer self.allocator.free(class_name);

                            try stack_frame.operand_stack.push(.{ .reference = try self.heap.newObject((try self.class_resolver.resolve(class_name)).?, self.class_resolver) });
                        },

                        .arraylength => try stack_frame.operand_stack.push(.{ .int = self.heap.getArray(stack_frame.operand_stack.pop().reference).length() }),

                        .iastore, .lastore, .fastore, .dastore, .aastore, .bastore, .castore, .sastore => {
                            var value = stack_frame.operand_stack.pop();
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { arrayref: primitives.reference, index: primitives.int });
                            try self.heap.getArray(stackvals.arrayref).set(stackvals.index, value);
                        },

                        .iaload, .laload, .faload, .daload, .aaload, .baload, .caload, .saload => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { arrayref: primitives.reference, index: primitives.int });
                            try stack_frame.operand_stack.push(try self.heap.getArray(stackvals.arrayref).get(stackvals.index));
                        },

                        // Invoke thangs
                        .invokestatic, .invokespecial, .invokevirtual => |index| {
                            var methodref = stack_frame.class_file.constant_pool.get(index).methodref;
                            var nti = methodref.getNameAndTypeInfo();
                            var class_info = methodref.getClassInfo();

                            var name = nti.getName().bytes;
                            var class_name_slashes = class_info.getName().bytes;
                            var class_name = class_name_slashes;
                            defer self.allocator.free(class_name);

                            try self.useStaticClass(class_name);

                            var descriptor_str = nti.getDescriptor().bytes;
                            var method_desc = try descriptors.parseString(self.allocator, descriptor_str);

                            var params = try self.allocator.alloc(primitives.PrimitiveValue, method_desc.method.parameters.len + if (opcode != .invokestatic) @as(usize, 1) else @as(usize, 0));

                            // std.log.info("{s} {s} {s} {s}", .{ class_name, name, descriptor_str, stack_frame.operand_stack.array_list.items });
                            var paramiiii: usize = method_desc.method.parameters.len;
                            while (paramiiii > 0) : (paramiiii -= 1) {
                                params[method_desc.method.parameters.len - paramiiii] = switch (method_desc.method.parameters[paramiiii - 1].*) {
                                    .byte => .{ .byte = stack_frame.operand_stack.pop().byte },
                                    .char => .{ .char = stack_frame.operand_stack.pop().char },

                                    .int, .boolean => .{ .int = stack_frame.operand_stack.pop().int },
                                    .long => .{ .long = stack_frame.operand_stack.pop().long },
                                    .short => .{ .short = stack_frame.operand_stack.pop().short },

                                    .float => .{ .float = stack_frame.operand_stack.pop().float },
                                    .double => .{ .double = stack_frame.operand_stack.pop().double },

                                    .object, .array => .{ .reference = stack_frame.operand_stack.pop().reference },
                                    .method => unreachable,

                                    else => unreachable,
                                };
                            }
                            if (opcode != .invokestatic) params[params.len - 1] = .{ .reference = stack_frame.operand_stack.pop().reference };
                            std.mem.reverse(primitives.PrimitiveValue, params);

                            var return_val = try self.interpret((try self.class_resolver.resolve(class_name)).?, name, params);
                            if (return_val != .void)
                                try stack_frame.operand_stack.push(return_val);

                            std.log.info("return to method: {s}", .{descriptor_buf.items});
                        },
                        .invokeinterface => |iiparams| {
                            var methodref = stack_frame.class_file.constant_pool.get(iiparams.index).interface_methodref;
                            var nti = methodref.getNameAndTypeInfo();
                            var class_info = methodref.getClassInfo();

                            var name = nti.getName().bytes;
                            var class_name_slashes = class_info.getName().bytes;
                            var class_name = class_name_slashes;
                            defer self.allocator.free(class_name);

                            try self.useStaticClass(class_name);

                            var descriptor_str = nti.getDescriptor().bytes;
                            var method_desc = try descriptors.parseString(self.allocator, descriptor_str);

                            var params = try self.allocator.alloc(primitives.PrimitiveValue, method_desc.method.parameters.len + 1);

                            // std.log.info("{s} {s} {s} {s}", .{ class_name, name, descriptor_str, stack_frame.operand_stack.array_list.items });
                            var paramiiii: usize = method_desc.method.parameters.len;
                            while (paramiiii > 0) : (paramiiii -= 1) {
                                params[method_desc.method.parameters.len - paramiiii] = switch (method_desc.method.parameters[paramiiii - 1].*) {
                                    .byte => .{ .byte = stack_frame.operand_stack.pop().byte },
                                    .char => .{ .char = stack_frame.operand_stack.pop().char },

                                    .int, .boolean => .{ .int = stack_frame.operand_stack.pop().int },
                                    .long => .{ .long = stack_frame.operand_stack.pop().long },
                                    .short => .{ .short = stack_frame.operand_stack.pop().short },

                                    .float => .{ .float = stack_frame.operand_stack.pop().float },
                                    .double => .{ .double = stack_frame.operand_stack.pop().double },

                                    .object, .array => .{ .reference = stack_frame.operand_stack.pop().reference },
                                    .method => unreachable,

                                    else => unreachable,
                                };
                            }
                            if (opcode != .invokestatic) params[params.len - 1] = .{ .reference = stack_frame.operand_stack.pop().reference };
                            std.mem.reverse(primitives.PrimitiveValue, params);

                            var return_val = try self.interpret(self.heap.getObject(params[0].reference).class_file, name, params);
                            if (return_val != .void)
                                try stack_frame.operand_stack.push(return_val);

                            std.log.info("return to method: {s}", .{descriptor_buf.items});
                        },

                        // Return
                        .ireturn, .freturn, .dreturn, .areturn => return stack_frame.operand_stack.pop(),
                        .@"return" => return .void,

                        // Comparisons
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Comparisons" for order
                        .lcmp => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.long, value2: primitives.long });
                            try stack_frame.operand_stack.push(.{ .int = if (stackvals.value1 == stackvals.value2) @as(primitives.int, 0) else if (stackvals.value1 > stackvals.value2) @as(primitives.int, 1) else @as(primitives.int, -1) });
                        },
                        .fcmpl, .fcmpg => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.float, value2: primitives.float });
                            try stack_frame.operand_stack.push(.{ .int = if (stackvals.value1 > stackvals.value2) @as(primitives.int, 1) else if (stackvals.value1 == stackvals.value2) @as(primitives.int, 0) else @as(primitives.int, -1) });
                        },
                        .dcmpl, .dcmpg => {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.double, value2: primitives.double });
                            try stack_frame.operand_stack.push(.{ .int = if (stackvals.value1 > stackvals.value2) @as(primitives.int, 1) else if (stackvals.value1 == stackvals.value2) @as(primitives.int, 0) else @as(primitives.int, -1) });
                        },

                        .ifeq => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value == 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .ifne => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value != 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },

                        .iflt => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value < 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .ifge => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value >= 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .ifgt => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value > 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .ifle => |offset| {
                            var value = stack_frame.operand_stack.pop().int;
                            if (value <= 0) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },

                        .if_icmpeq => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 == stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_icmpne => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 != stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_icmplt => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 < stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_icmpge => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 >= stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_icmpgt => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 > stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_icmple => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.int, value2: primitives.int });
                            if (stackvals.value1 <= stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },

                        .if_acmpeq => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.reference, value2: primitives.reference });
                            if (stackvals.value1 == stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },
                        .if_acmpne => |offset| {
                            var stackvals = stack_frame.operand_stack.popToStruct(struct { value1: primitives.reference, value2: primitives.reference });
                            if (stackvals.value1 != stackvals.value2) {
                                try fbs.seekBy(offset - @intCast(i16, opcode.sizeOf()));
                            }
                        },

                        // References
                        // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "References" for order
                        .getstatic => |index| {
                            var fieldref = stack_frame.class_file.constant_pool.get(index).fieldref;

                            var nti = fieldref.getNameAndTypeInfo();
                            var name = nti.getName().bytes;
                            var class_name_slashes = fieldref.getClassInfo().getName().bytes;
                            var class_name = class_name_slashes;
                            defer self.allocator.free(class_name);

                            try self.useStaticClass(class_name);

                            var class = self.static_pool.getClass(class_name).?;
                            try stack_frame.operand_stack.push(class.getField(name).?);
                        },
                        .putstatic => |index| {
                            var fieldref = stack_frame.class_file.constant_pool.get(index).fieldref;

                            var nti = fieldref.getNameAndTypeInfo();
                            var name = nti.getName().bytes;
                            var class_name_slashes = fieldref.getClassInfo().getName().bytes;
                            var class_name = class_name_slashes;
                            defer self.allocator.free(class_name);

                            try self.useStaticClass(class_name);

                            var value = stack_frame.operand_stack.pop();

                            try (self.static_pool.getClass(class_name).?).setField(name, value);
                        },
                        .getfield => |index| {
                            var fieldref = stack_frame.class_file.constant_pool.get(index).fieldref;

                            var nti = fieldref.getNameAndTypeInfo();
                            var name = nti.getName().bytes;

                            var objectref = stack_frame.operand_stack.pop().reference;

                            try stack_frame.operand_stack.push(self.heap.getObject(objectref).getField(name).?);
                        },
                        .putfield => |index| {
                            var fieldref = stack_frame.class_file.constant_pool.get(index).fieldref;

                            var nti = fieldref.getNameAndTypeInfo();
                            var name = nti.getName().bytes;

                            var value = stack_frame.operand_stack.pop();
                            var objectref = stack_frame.operand_stack.pop().reference;

                            try self.heap.getObject(objectref).setField(name, value);
                        },

                        .tableswitch => |s| {
                            var size = 1 + s.skipped_bytes + 4 * 3 + 4 * s.jumps.len;
                            var index = stack_frame.operand_stack.pop().int;

                            if (index < 0 or index >= s.jumps.len) {
                                try fbs.seekBy(s.default_offset - @intCast(i32, size));
                            } else {
                                try fbs.seekBy(s.jumps[@intCast(usize, index)] - @intCast(i32, size));
                            }
                        },

                        .lookupswitch => |s| z: {
                            var size = 1 + s.skipped_bytes + 4 * 2 + 8 * s.pairs.len;
                            var match = stack_frame.operand_stack.pop().int;

                            for (s.pairs) |pair| {
                                if (match == pair.match) {
                                    try fbs.seekBy(pair.offset - @intCast(i32, size));
                                    break :z;
                                }
                            }

                            try fbs.seekBy(s.default_offset - @intCast(i32, size));
                        },

                        else => unreachable,
                    }
                    opcode = opcodes.Operation.decode(self.allocator, fbs_reader) catch break;
                }
            },
            else => {},
        }
    }

    unreachable;
}
