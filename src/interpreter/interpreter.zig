const std = @import("std");

const Heap = @import("heap.zig");
const array = @import("array.zig");
const utils = @import("utils.zig");
const Object = @import("Object.zig");
const StaticPool = @import("StaticPool.zig");
const StackFrame = @import("StackFrame.zig");
const primitives = @import("primitives.zig");
const ClassResolver = @import("ClassResolver.zig");

const opcodes = @import("../types/opcodes.zig");
const methods = @import("../types/methods.zig");
const ClassFile = @import("../types/ClassFile.zig");
const attributes = @import("../types/attributes.zig");
const descriptors = @import("../types/descriptors.zig");
const constant_pool = @import("../types/constant_pool.zig");

const Interpreter = @This();

allocator: *std.mem.Allocator,
heap: Heap,
static_pool: StaticPool,
class_resolver: ClassResolver,

pub fn init(allocator: *std.mem.Allocator, class_resolver: ClassResolver) Interpreter {
    return .{ .allocator = allocator, .heap = Heap.init(allocator), .static_pool = StaticPool.init(allocator), .class_resolver = class_resolver };
}

pub fn call(self: *Interpreter, path: []const u8, args: anytype) !primitives.PrimitiveValue {
    var class_file = try self.class_resolver.resolve(path[0..std.mem.lastIndexOf(u8, path, ".").?]);
    var method_name = path[std.mem.lastIndexOf(u8, path, ".").? + 1 ..];
    var margs: [std.meta.fields(@TypeOf(args)).len]primitives.PrimitiveValue = undefined;

    var method_info: ?methods.MethodInfo = null;
    for (class_file.methods) |*m| {
        if (!std.mem.eql(u8, m.getName(class_file), method_name)) continue;

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

        _ = self.call(clname, .{}) catch |err| switch (err) {
            error.ClassNotFound => @panic("Big problem!!!"),
            error.MethodNotFound => {},
            else => unreachable,
        };
    }
}

pub fn newObject(self: *Interpreter, class_name: []const u8) !primitives.reference {
    return try self.heap.newObject(try self.class_resolver.resolve(class_name));
}

pub fn new(self: *Interpreter, class_name: []const u8, args: anytype) !primitives.reference {
    var inits = try std.mem.concat(self.allocator, u8, &.{ class_name, ".<init>" });
    defer self.allocator.free(inits);

    var object = try self.newObject(class_name);
    _ = try self.call(inits, .{object} ++ args);
    return object;
}

fn interpret(self: *Interpreter, class_file: ClassFile, method_name: []const u8, args: []primitives.PrimitiveValue) anyerror!primitives.PrimitiveValue {
    var descriptor_buf = std.ArrayList(u8).init(self.allocator);
    defer descriptor_buf.deinit();

    method_search: for (class_file.methods) |*method| {
        if (!std.mem.eql(u8, method.getName(class_file), method_name)) continue;
        var method_descriptor_str = method.getDescriptor(class_file);
        var method_descriptor = try descriptors.parseString(self.allocator, method_descriptor_str);

        if (method_descriptor.method.parameters.len != args.len - if (method.access_flags.static) @as(usize, 0) else @as(usize, 1)) continue;

        var parami = if (method.access_flags.static) @as(usize, 0) else @as(usize, 1);
        while (parami < method_descriptor.method.parameters.len) : (parami += 1) {
            var param = method_descriptor.method.parameters[parami];
            switch (param.*) {
                .int => if (args[parami] != .int) continue :method_search,
                .object => |o| {
                    switch (self.heap.get(args[parami].reference).*) {
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
                else => unreachable,
            }
        }

        descriptor_buf.shrinkRetainingCapacity(0);
        try utils.formatMethod(self.allocator, class_file, method, descriptor_buf.writer());
        std.log.info("method: {s}", .{descriptor_buf.items});

        // TODO: See descriptors.zig
        for (method.attributes) |*att| {
            var data = try att.readData(self.allocator, class_file);
            std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{att.getName(class_file)});

            switch (data) {
                .code => |code_attribute| {
                    var stack_frame = StackFrame.init(self.allocator, class_file);
                    defer stack_frame.deinit();

                    try stack_frame.local_variables.appendSlice(args);

                    var fbs = std.io.fixedBufferStream(code_attribute.code);
                    var fbs_reader = fbs.reader();

                    var opcode = try opcodes.Operation.readFrom(fbs_reader);

                    while (true) {
                        std.log.info((" " ** 8) ++ "{s}", .{opcode});

                        // TODO: Rearrange everything according to https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html
                        switch (opcode) {
                            // Constants
                            // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Constants" for order
                            .nop => {},
                            .aconst_null => try stack_frame.operand_stack.push(.@"null"),

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

                            .iload => |i| try stack_frame.operand_stack.push(.{ .int = stack_frame.local_variables.items[i].int }),
                            .iload_0 => try stack_frame.operand_stack.push(.{ .int = stack_frame.local_variables.items[0].int }),
                            .iload_1 => try stack_frame.operand_stack.push(.{ .int = stack_frame.local_variables.items[1].int }),
                            .iload_2 => try stack_frame.operand_stack.push(.{ .int = stack_frame.local_variables.items[2].int }),
                            .iload_3 => try stack_frame.operand_stack.push(.{ .int = stack_frame.local_variables.items[3].int }),

                            .istore => |i| try stack_frame.setLocalVariable(i, .{ .int = stack_frame.operand_stack.pop().int }),
                            .istore_0 => try stack_frame.setLocalVariable(0, .{ .int = stack_frame.operand_stack.pop().int }),
                            .istore_1 => try stack_frame.setLocalVariable(1, .{ .int = stack_frame.operand_stack.pop().int }),
                            .istore_2 => try stack_frame.setLocalVariable(2, .{ .int = stack_frame.operand_stack.pop().int }),
                            .istore_3 => try stack_frame.setLocalVariable(3, .{ .int = stack_frame.operand_stack.pop().int }),

                            .bipush => |value| try stack_frame.operand_stack.push(.{ .int = value }),
                            .sipush => |value| try stack_frame.operand_stack.push(.{ .int = value }),

                            .ldc => |index| {
                                switch (stack_frame.class_file.resolveConstant(index)) {
                                    .integer => |f| try stack_frame.operand_stack.push(.{ .int = @bitCast(primitives.int, f) }),
                                    .float => |f| try stack_frame.operand_stack.push(.{ .float = @bitCast(primitives.float, f) }),
                                    .string => |s| {
                                        var utf8 = class_file.resolveConstant(s.string_index).utf8;
                                        var ref = try self.heap.newArray(.byte, @intCast(primitives.int, utf8.bytes.len));
                                        var arr = self.heap.getArray(ref);

                                        std.mem.copy(i8, arr.byte.slice, @bitCast([]i8, utf8.bytes));

                                        try stack_frame.operand_stack.push(.{ .reference = try self.new("java.lang.String", .{ref}) });
                                    },
                                    else => {
                                        std.log.info("{s}", .{stack_frame.class_file.resolveConstant(index)});
                                        unreachable;
                                    },
                                }
                            },
                            .ldc_w => |index| {
                                switch (stack_frame.class_file.resolveConstant(index)) {
                                    .integer => |f| try stack_frame.operand_stack.push(.{ .int = @bitCast(primitives.int, f) }),
                                    .float => |f| try stack_frame.operand_stack.push(.{ .float = @bitCast(primitives.float, f) }),
                                    .string => |s| {
                                        var utf8 = class_file.resolveConstant(s.string_index).utf8;
                                        var ref = try self.heap.newArray(.byte, @intCast(primitives.int, utf8.bytes.len));
                                        var arr = self.heap.getArray(ref);

                                        std.mem.copy(i8, arr.byte.slice, @bitCast([]i8, utf8.bytes));

                                        try stack_frame.operand_stack.push(.{ .reference = try self.new("java.lang.String", .{ref}) });
                                    },
                                    else => {
                                        std.log.info("{s}", .{stack_frame.class_file.resolveConstant(index)});
                                        unreachable;
                                    },
                                }
                            },
                            .ldc2_w => |index| {
                                switch (stack_frame.class_file.resolveConstant(index)) {
                                    .double => |d| try stack_frame.operand_stack.push(.{ .double = @bitCast(primitives.double, d) }),
                                    .long => |l| try stack_frame.operand_stack.push(.{ .long = @bitCast(primitives.long, l) }),
                                    else => unreachable,
                                }
                            },

                            // Loads
                            // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Loads" for order

                            .iinc => |iinc| stack_frame.local_variables.items[iinc.index].int += iinc.@"const",

                            .fload => |i| try stack_frame.operand_stack.push(.{ .float = stack_frame.local_variables.items[i].float }),
                            .fload_0 => try stack_frame.operand_stack.push(.{ .float = stack_frame.local_variables.items[0].float }),
                            .fload_1 => try stack_frame.operand_stack.push(.{ .float = stack_frame.local_variables.items[1].float }),
                            .fload_2 => try stack_frame.operand_stack.push(.{ .float = stack_frame.local_variables.items[2].float }),
                            .fload_3 => try stack_frame.operand_stack.push(.{ .float = stack_frame.local_variables.items[3].float }),

                            .fstore => |i| try stack_frame.setLocalVariable(i, .{ .float = stack_frame.operand_stack.pop().float }),
                            .fstore_0 => try stack_frame.setLocalVariable(0, .{ .float = stack_frame.operand_stack.pop().float }),
                            .fstore_1 => try stack_frame.setLocalVariable(1, .{ .float = stack_frame.operand_stack.pop().float }),
                            .fstore_2 => try stack_frame.setLocalVariable(2, .{ .float = stack_frame.operand_stack.pop().float }),
                            .fstore_3 => try stack_frame.setLocalVariable(3, .{ .float = stack_frame.operand_stack.pop().float }),

                            .dload => |i| try stack_frame.operand_stack.push(.{ .double = stack_frame.local_variables.items[i].double }),
                            .dload_0 => try stack_frame.operand_stack.push(.{ .double = stack_frame.local_variables.items[0].double }),
                            .dload_1 => try stack_frame.operand_stack.push(.{ .double = stack_frame.local_variables.items[1].double }),
                            .dload_2 => try stack_frame.operand_stack.push(.{ .double = stack_frame.local_variables.items[2].double }),
                            .dload_3 => try stack_frame.operand_stack.push(.{ .double = stack_frame.local_variables.items[3].double }),

                            .dstore => |i| try stack_frame.setLocalVariable(i, .{ .double = stack_frame.operand_stack.pop().double }),
                            .dstore_0 => try stack_frame.setLocalVariable(0, .{ .double = stack_frame.operand_stack.pop().double }),
                            .dstore_1 => try stack_frame.setLocalVariable(1, .{ .double = stack_frame.operand_stack.pop().double }),
                            .dstore_2 => try stack_frame.setLocalVariable(2, .{ .double = stack_frame.operand_stack.pop().double }),
                            .dstore_3 => try stack_frame.setLocalVariable(3, .{ .double = stack_frame.operand_stack.pop().double }),

                            .aload => |i| try stack_frame.operand_stack.push(.{ .reference = stack_frame.local_variables.items[i].reference }),
                            .aload_0 => try stack_frame.operand_stack.push(.{ .reference = stack_frame.local_variables.items[0].reference }),
                            .aload_1 => try stack_frame.operand_stack.push(.{ .reference = stack_frame.local_variables.items[1].reference }),
                            .aload_2 => try stack_frame.operand_stack.push(.{ .reference = stack_frame.local_variables.items[2].reference }),
                            .aload_3 => try stack_frame.operand_stack.push(.{ .reference = stack_frame.local_variables.items[3].reference }),

                            .astore => |i| try stack_frame.setLocalVariable(i, .{ .reference = stack_frame.operand_stack.pop().reference }),
                            .astore_0 => try stack_frame.setLocalVariable(0, .{ .reference = stack_frame.operand_stack.pop().reference }),
                            .astore_1 => try stack_frame.setLocalVariable(1, .{ .reference = stack_frame.operand_stack.pop().reference }),
                            .astore_2 => try stack_frame.setLocalVariable(2, .{ .reference = stack_frame.operand_stack.pop().reference }),
                            .astore_3 => try stack_frame.setLocalVariable(3, .{ .reference = stack_frame.operand_stack.pop().reference }),

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
                            // See https://docs.oracle.com/javase/specs/jvms/se16/html/jvms-7.html, subsection "Conversions" for order
                            .i2l => try stack_frame.operand_stack.push(.{ .long = @intCast(primitives.long, stack_frame.operand_stack.pop().int) }),
                            .i2f => try stack_frame.operand_stack.push(.{ .float = @intToFloat(primitives.float, stack_frame.operand_stack.pop().int) }),
                            .i2d => try stack_frame.operand_stack.push(.{ .double = @intToFloat(primitives.double, stack_frame.operand_stack.pop().int) }),

                            .l2i => try stack_frame.operand_stack.push(.{ .int = @intCast(primitives.int, stack_frame.operand_stack.pop().long) }),
                            .l2f => try stack_frame.operand_stack.push(.{ .float = @intToFloat(primitives.float, stack_frame.operand_stack.pop().long) }),
                            .l2d => try stack_frame.operand_stack.push(.{ .double = @intToFloat(primitives.double, stack_frame.operand_stack.pop().long) }),

                            .f2i => try stack_frame.operand_stack.push(.{ .int = @floatToInt(primitives.int, stack_frame.operand_stack.pop().float) }),
                            .f2l => try stack_frame.operand_stack.push(.{ .long = @floatToInt(primitives.long, stack_frame.operand_stack.pop().float) }),
                            .f2d => try stack_frame.operand_stack.push(.{ .double = @floatCast(primitives.double, stack_frame.operand_stack.pop().float) }),

                            .d2i => try stack_frame.operand_stack.push(.{ .int = @floatToInt(primitives.int, stack_frame.operand_stack.pop().double) }),
                            .d2l => try stack_frame.operand_stack.push(.{ .long = @floatToInt(primitives.long, stack_frame.operand_stack.pop().double) }),
                            .d2f => try stack_frame.operand_stack.push(.{ .float = @floatCast(primitives.float, stack_frame.operand_stack.pop().double) }),

                            .i2b => try stack_frame.operand_stack.push(.{ .byte = @intCast(primitives.byte, stack_frame.operand_stack.pop().int) }),
                            .i2c => try stack_frame.operand_stack.push(.{ .char = @intCast(primitives.char, stack_frame.operand_stack.pop().int) }),
                            .i2s => try stack_frame.operand_stack.push(.{ .short = @intCast(primitives.short, stack_frame.operand_stack.pop().int) }),

                            // Java bad
                            .newarray => |atype| {
                                inline for (std.meta.fields(@TypeOf(atype))) |field| {
                                    if (atype == @intToEnum(@TypeOf(atype), field.value))
                                        try stack_frame.operand_stack.push(.{ .reference = try self.heap.newArray(std.meta.stringToEnum(array.ArrayKind, field.name).?, stack_frame.operand_stack.pop().int) });
                                }
                            },
                            .new => |index| {
                                var class_name_slashes = class_file.resolveConstant(index).class.getName(class_file.constant_pool);
                                var class_name = try utils.classToDots(self.allocator, class_name_slashes);
                                defer self.allocator.free(class_name);

                                try stack_frame.operand_stack.push(.{ .reference = try self.heap.newObject(try self.class_resolver.resolve(class_name)) });
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
                            .invokestatic, .invokespecial => |index| {
                                var methodref = stack_frame.class_file.resolveConstant(index).methodref;
                                var nti = methodref.getNameAndTypeInfo(class_file.constant_pool);
                                var class_info = methodref.getClassInfo(class_file.constant_pool);

                                var name = nti.getName(class_file.constant_pool);
                                var class_name_slashes = class_info.getName(class_file.constant_pool);
                                var class_name = try utils.classToDots(self.allocator, class_name_slashes);
                                defer self.allocator.free(class_name);

                                try self.useStaticClass(class_name);

                                var descriptor_str = nti.getDescriptor(class_file.constant_pool);
                                var method_desc = try descriptors.parseString(self.allocator, descriptor_str);

                                var params = try self.allocator.alloc(primitives.PrimitiveValue, method_desc.method.parameters.len + if (opcode != .invokestatic) @as(usize, 1) else @as(usize, 0));

                                for (method_desc.method.parameters) |param, i| {
                                    params[i] = switch (param.*) {
                                        .byte => .{ .byte = stack_frame.operand_stack.pop().byte },
                                        .char => .{ .char = stack_frame.operand_stack.pop().char },

                                        .int, .boolean => .{ .int = stack_frame.operand_stack.pop().int },
                                        .long => .{ .long = stack_frame.operand_stack.pop().long },
                                        .short => .{ .short = stack_frame.operand_stack.pop().short },

                                        .float => .{ .float = stack_frame.operand_stack.pop().float },
                                        .double => .{ .double = stack_frame.operand_stack.pop().double },

                                        .object => .{ .reference = stack_frame.operand_stack.pop().reference },
                                        .array, .method => unreachable,

                                        else => unreachable,
                                    };
                                }
                                if (opcode != .invokestatic) params[params.len - 1] = .{ .reference = stack_frame.operand_stack.pop().reference };
                                std.mem.reverse(primitives.PrimitiveValue, params);

                                var return_val = try self.interpret(try self.class_resolver.resolve(class_name), name, params);
                                if (return_val != .@"void")
                                    try stack_frame.operand_stack.push(return_val);

                                std.log.info("return to method: {s}", .{descriptor_buf.items});
                            },

                            // Return
                            .ireturn, .freturn, .dreturn, .areturn => return stack_frame.operand_stack.pop(),
                            .@"return" => return .@"void",

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
                                var fieldref = stack_frame.class_file.resolveConstant(index).fieldref;

                                var nti = fieldref.getNameAndTypeInfo(class_file.constant_pool);
                                var name = nti.getName(class_file.constant_pool);
                                var class_name_slashes = fieldref.getClassInfo(class_file.constant_pool).getName(class_file.constant_pool);
                                var class_name = try utils.classToDots(self.allocator, class_name_slashes);
                                defer self.allocator.free(class_name);

                                try self.useStaticClass(class_name);

                                var class = try self.static_pool.getClass(class_name);
                                try stack_frame.operand_stack.push(class.getField(name).?);
                            },
                            .putstatic => |index| {
                                var fieldref = stack_frame.class_file.resolveConstant(index).fieldref;

                                var nti = fieldref.getNameAndTypeInfo(class_file.constant_pool);
                                var name = nti.getName(class_file.constant_pool);
                                var class_name_slashes = fieldref.getClassInfo(class_file.constant_pool).getName(class_file.constant_pool);
                                var class_name = try utils.classToDots(self.allocator, class_name_slashes);
                                defer self.allocator.free(class_name);

                                try self.useStaticClass(class_name);

                                var value = stack_frame.operand_stack.pop();

                                try (try self.static_pool.getClass(class_name)).setField(name, value);
                            },
                            .getfield => |index| {
                                var fieldref = stack_frame.class_file.resolveConstant(index).fieldref;

                                var nti = fieldref.getNameAndTypeInfo(class_file.constant_pool);
                                var name = nti.getName(class_file.constant_pool);

                                var objectref = stack_frame.operand_stack.pop().reference;

                                try stack_frame.operand_stack.push(self.heap.getObject(objectref).getField(name).?);
                            },
                            .putfield => |index| {
                                var fieldref = stack_frame.class_file.resolveConstant(index).fieldref;

                                var nti = fieldref.getNameAndTypeInfo(class_file.constant_pool);
                                var name = nti.getName(class_file.constant_pool);

                                var value = stack_frame.operand_stack.pop();
                                var objectref = stack_frame.operand_stack.pop().reference;

                                try self.heap.getObject(objectref).setField(name, value);
                            },

                            else => unreachable,
                        }
                        opcode = opcodes.Operation.readFrom(fbs_reader) catch break;
                    }
                },
                .unknown => {},
            }
        }
    }

    return error.MethodNotFound;
}
