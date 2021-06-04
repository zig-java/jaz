const std = @import("std");

const StackFrame = @import("StackFrame.zig");
const primitives = @import("primitives.zig");

const opcodes = @import("../types/opcodes.zig");
const methods = @import("../types/methods.zig");
const ClassFile = @import("../types/ClassFile.zig");
const attributes = @import("../types/attributes.zig");
const descriptors = @import("../types/descriptors.zig");
const constant_pool = @import("../types/constant_pool.zig");

pub fn formatMethod(allocator: *std.mem.Allocator, class_file: ClassFile, method: *methods.MethodInfo, writer: anytype) !void {
    if (method.access_flags.public) _ = try writer.writeAll("public ");
    if (method.access_flags.private) _ = try writer.writeAll("private ");
    if (method.access_flags.protected) _ = try writer.writeAll("protected ");

    if (method.access_flags.static) _ = try writer.writeAll("static ");
    if (method.access_flags.abstract) _ = try writer.writeAll("abstract ");
    if (method.access_flags.final) _ = try writer.writeAll("final ");

    var desc = method.getDescriptor(class_file);
    var fbs = std.io.fixedBufferStream(desc);
    
    // Write human readable return descriptor
    var descriptor = try descriptors.parse(allocator, fbs.reader());
    try descriptor.method.return_type.humanStringify(writer);

    // Write human readable parameters descriptor
    try writer.writeByte(' ');
    _ = try writer.writeAll(method.getName(class_file));
    try writer.writeByte('(');
    for (descriptor.method.parameters) |param, i| {
        try param.humanStringify(writer);
        if (i + 1 != descriptor.method.parameters.len) _ = try writer.writeAll(", ");
    }
    try writer.writeByte(')');
}

pub fn interpret(allocator: *std.mem.Allocator, class_file: ClassFile, method_name: []const u8, args: []primitives.PrimitiveValue) !primitives.PrimitiveValue {
    var w = std.ArrayList(u8).init(allocator);
    defer w.deinit();

    for (class_file.methods) |*method| {
        if (!std.mem.eql(u8, method.getName(class_file), method_name)) continue;

        w.shrinkRetainingCapacity(0);
        try formatMethod(allocator, class_file, method, w.writer());
        std.log.info("method: {s}", .{w.items});

        // TODO: See descriptors.zig
        for (method.attributes) |*att| {
            var data = try att.readData(allocator, class_file);
            std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{att.getName(class_file)});
            
            switch (data) {
                .code => |code_attribute| {
                    var s = StackFrame.init(allocator, class_file);
                    defer s.deinit();

                    try s.local_variables.appendSlice(args);
                    
                    var fbs = std.io.fixedBufferStream(code_attribute.code);
                    var fbs_reader = fbs.reader();
                
                    var k = try opcodes.Operation.readFrom(fbs_reader);

                    // TODO: Refactor this garbage somehow
                    while (true) {
                        std.log.info((" " ** 8) ++ "{s}", .{k});
                        // std.log.info((" " ** 8) ++ "{s}", .{s.local_variables.items[0]});
                        switch (k) {
                            .iload => |i| try s.operand_stack.push(.{ .int = s.local_variables.items[i].int }),
                            .iload_0 => try s.operand_stack.push(.{ .int = s.local_variables.items[0].int }),
                            .iload_1 => try s.operand_stack.push(.{ .int = s.local_variables.items[1].int }),
                            .iload_2 => try s.operand_stack.push(.{ .int = s.local_variables.items[2].int }),
                            .iload_3 => try s.operand_stack.push(.{ .int = s.local_variables.items[3].int }),

                            .istore => |i| try s.setLocalVariable(i, .{ .int = s.operand_stack.pop().int }),
                            .istore_0 => try s.setLocalVariable(0, .{ .int = s.operand_stack.pop().int }),
                            .istore_1 => try s.setLocalVariable(1, .{ .int = s.operand_stack.pop().int }),
                            .istore_2 => try s.setLocalVariable(2, .{ .int = s.operand_stack.pop().int }),
                            .istore_3 => try s.setLocalVariable(3, .{ .int = s.operand_stack.pop().int }),

                            .sipush => |value| try s.operand_stack.push(.{ .int = value }),
                            .bipush => |value| try s.operand_stack.push(.{ .int = value }),
                            .ldc => |index| {
                                switch (s.class_file.resolveConstant(index)) {
                                    .float => |f| try s.operand_stack.push(.{ .float = @bitCast(f32, f) }),
                                    else => unreachable
                                }
                            },
                            .iinc => |iinc| s.local_variables.items[iinc.index].int += iinc.@"const",

                            .fload => |i| try s.operand_stack.push(.{ .float = s.local_variables.items[i].float }),
                            .fload_0 => try s.operand_stack.push(.{ .float = s.local_variables.items[0].float }),
                            .fload_1 => try s.operand_stack.push(.{ .float = s.local_variables.items[1].float }),
                            .fload_2 => try s.operand_stack.push(.{ .float = s.local_variables.items[2].float }),
                            .fload_3 => try s.operand_stack.push(.{ .float = s.local_variables.items[3].float }),

                            .fstore => |i| try s.setLocalVariable(i, .{ .float = s.operand_stack.pop().float }),
                            .fstore_0 => try s.setLocalVariable(0, .{ .float = s.operand_stack.pop().float }),
                            .fstore_1 => try s.setLocalVariable(1, .{ .float = s.operand_stack.pop().float }),
                            .fstore_2 => try s.setLocalVariable(2, .{ .float = s.operand_stack.pop().float }),
                            .fstore_3 => try s.setLocalVariable(3, .{ .float = s.operand_stack.pop().float }),

                            .dload => |i| try s.operand_stack.push(.{ .double = s.local_variables.items[i].double }),
                            .dload_0 => try s.operand_stack.push(.{ .double = s.local_variables.items[0].double }),
                            .dload_1 => try s.operand_stack.push(.{ .double = s.local_variables.items[1].double }),
                            .dload_2 => try s.operand_stack.push(.{ .double = s.local_variables.items[2].double }),
                            .dload_3 => try s.operand_stack.push(.{ .double = s.local_variables.items[3].double }),

                            .iconst_m1 => try s.operand_stack.push(.{ .int = -1 }),
                            .iconst_0 => try s.operand_stack.push(.{ .int = 0 }),
                            .iconst_1 => try s.operand_stack.push(.{ .int = 1 }),
                            .iconst_2 => try s.operand_stack.push(.{ .int = 2 }),
                            .iconst_3 => try s.operand_stack.push(.{ .int = 3 }),
                            .iconst_4 => try s.operand_stack.push(.{ .int = 4 }),
                            .iconst_5 => try s.operand_stack.push(.{ .int = 5 }),

                            .fconst_0 => try s.operand_stack.push(.{ .float = 0 }),
                            .fconst_1 => try s.operand_stack.push(.{ .float = 1 }),
                            .fconst_2 => try s.operand_stack.push(.{ .float = 2 }),

                            .dconst_0 => try s.operand_stack.push(.{ .double = 0 }),
                            .dconst_1 => try s.operand_stack.push(.{ .double = 1 }),

                            .iadd => try s.operand_stack.push(.{ .int = s.operand_stack.pop().int + s.operand_stack.pop().int }),
                            .imul => try s.operand_stack.push(.{ .int = s.operand_stack.pop().int * s.operand_stack.pop().int }),
                            .isub => {
                                var stackvals = s.operand_stack.popToStruct(struct {a: primitives.int, b: primitives.int});
                                try s.operand_stack.push(.{ .int = stackvals.a - stackvals.b });
                            },
                            .idiv => {
                                var stackvals = s.operand_stack.popToStruct(struct {numerator: primitives.int, denominator: primitives.int});
                                try s.operand_stack.push(.{ .int = @divTrunc(stackvals.numerator, stackvals.denominator) });
                            },

                            .fadd => try s.operand_stack.push(.{ .float = s.operand_stack.pop().float + s.operand_stack.pop().float }),
                            .fmul => try s.operand_stack.push(.{ .float = s.operand_stack.pop().float * s.operand_stack.pop().float }),
                            .fsub => {
                                var stackvals = s.operand_stack.popToStruct(struct {a: primitives.float, b: primitives.float});
                                try s.operand_stack.push(.{ .float = stackvals.a - stackvals.b });
                            },
                            .fdiv => {
                                var stackvals = s.operand_stack.popToStruct(struct {numerator: primitives.float, denominator: primitives.float});
                                try s.operand_stack.push(.{ .float = stackvals.numerator / stackvals.denominator });
                            },

                            .dadd => try s.operand_stack.push(.{ .double = s.operand_stack.pop().double + s.operand_stack.pop().double }),
                            .dmul => try s.operand_stack.push(.{ .double = s.operand_stack.pop().double * s.operand_stack.pop().double }),
                            .dsub => {
                                var stackvals = s.operand_stack.popToStruct(struct {a: primitives.double, b: primitives.double});
                                try s.operand_stack.push(.{ .double = stackvals.a - stackvals.b });
                            },
                            .ddiv => {
                                var stackvals = s.operand_stack.popToStruct(struct {numerator: primitives.double, denominator: primitives.double});
                                try s.operand_stack.push(.{ .double = stackvals.numerator / stackvals.denominator });
                            },

                            // Conditionals / jumps
                            // TODO: Implement all conditions (int comparison, 0 comparison, etc.)
                            .goto => |offset| {
                                try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                            },
                            
                            .if_icmple => |offset| {
                                var stackvals = s.operand_stack.popToStruct(struct {value1: primitives.int, value2: primitives.int});
                                if (stackvals.value1 <= stackvals.value2) {
                                    try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                                }
                            },
                            .if_icmpge => |offset| {
                                var stackvals = s.operand_stack.popToStruct(struct {value1: primitives.int, value2: primitives.int});
                                if (stackvals.value1 >= stackvals.value2) {
                                    try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                                }
                            },
                            .if_icmpne => |offset| {
                                var stackvals = s.operand_stack.popToStruct(struct {value1: primitives.int, value2: primitives.int});
                                if (stackvals.value1 != stackvals.value2) {
                                    try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                                }
                            },

                            .iflt => |offset| {
                                var value = s.operand_stack.pop().int;
                                if (value < 0) {
                                    try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                                }
                            },
                            .ifle => |offset| {
                                var value = s.operand_stack.pop().int;
                                if (value <= 0) {
                                    try fbs.seekBy(offset - @intCast(i16, k.sizeOf()));
                                }
                            },

                            .fcmpg, .fcmpl => {
                                var stackvals = s.operand_stack.popToStruct(struct {value1: primitives.float, value2: primitives.float});
                                try s.operand_stack.push(.{
                                    .int = if (stackvals.value1 > stackvals.value2) @as(primitives.int, 1) else if (stackvals.value1 == stackvals.value2) @as(primitives.int, 0) else @as(primitives.int, -1)
                                });
                            },

                            // Casts
                            .i2b => try s.operand_stack.push(.{ .byte = @intCast(primitives.byte, s.operand_stack.pop().int) }),
                            .i2c =>try s.operand_stack.push(.{ .char = @intCast(primitives.char, s.operand_stack.pop().int) }),
                            .i2d => try s.operand_stack.push(.{ .double = @intToFloat(primitives.double, s.operand_stack.pop().int) }),
                            .i2f => try s.operand_stack.push(.{ .float = @intToFloat(primitives.float, s.operand_stack.pop().int) }),
                            .i2l => try s.operand_stack.push(.{ .long = @intCast(primitives.long, s.operand_stack.pop().int) }),
                            .i2s => try s.operand_stack.push(.{ .short = @intCast(primitives.short, s.operand_stack.pop().int) }),

                            .f2i => try s.operand_stack.push(.{ .int = @floatToInt(primitives.int, s.operand_stack.pop().float) }),

                            // Return
                            .ireturn, .freturn, .dreturn => return s.operand_stack.pop(),
                            .@"return" => return .@"void",

                            else => {}
                        }
                        k = opcodes.Operation.readFrom(fbs_reader) catch break;
                    }
                },
                .unknown => {}
            }
        }
    }

    return .@"void";
}

pub fn interpretA() !void {
    std.log.info("this class: {s} {s}", .{class_file.this_class.getName(class_file.constant_pool), class_file.access_flags});

    for (class_file.constant_pool) |cp| {
        switch (cp) {
            .utf8, .name_and_type, .string => {},
            .fieldref, .methodref, .interface_methodref => |ref| {
                var nti = ref.getNameAndTypeInfo(class_file.constant_pool);
                std.log.info("ref: class '{s}' name '{s} {s}'", .{ref.getClassInfo(class_file.constant_pool).getName(class_file.constant_pool), nti.getName(class_file.constant_pool), nti.getDescriptor(class_file.constant_pool)});
            },
            .class => |clz| {
                std.log.info("class: {s}", .{clz.getName(class_file.constant_pool)});
            },
            .method_handle => |handle| {
                std.log.info("method handle: {s}", .{handle.getReference(class_file.constant_pool)});
            },
            else => |o| std.log.info("OTHER: {s}", .{o})
        }
    }

    for (class_file.fields) |*field| {
        var desc = try descriptors.parseString(allocator, field.getDescriptor(class_file));
        defer desc.deinit(allocator);

        try desc.toHumanStringArrayList(&w);
        std.log.info("field: '{s}' of type '{s}'", .{field.getName(class_file), w.items});
    }

    for (class_file.attributes) |*attribute| {
        std.log.info("class attribute: '{s}'", .{attribute.getName(class_file)});
    }
}
