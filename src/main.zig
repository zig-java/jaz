const std = @import("std");
const opcodes = @import("types/opcodes.zig");
const methods = @import("types/methods.zig");
const ClassFile = @import("types/ClassFile.zig");
const attributes = @import("types/attributes.zig");
const descriptors = @import("types/descriptors.zig");
const constant_pool = @import("types/constant_pool.zig");

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

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var testClass = try std.fs.cwd().openFile("sample/Test.class", .{});
    defer testClass.close();

    var testReader = testClass.reader();
    var class_file = try ClassFile.readFrom(allocator, testReader);
    
    std.log.info("this class: {s} {s}", .{class_file.this_class.getName(class_file.constant_pool), class_file.access_flags});

    var w = std.ArrayList(u8).init(allocator);
    defer w.deinit();

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

    for (class_file.methods) |*method| {
        w.shrinkRetainingCapacity(0);
        try formatMethod(allocator, class_file, method, w.writer());
        std.log.info("method: {s}", .{w.items});

        // TODO: See descriptors.zig
        for (method.attributes) |*att| {
            var data = try att.readData(allocator, class_file);
            std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{att.getName(class_file)});
            
            switch (data) {
                .code => |code_attribute| {
                    var fbs = std.io.fixedBufferStream(code_attribute.code);
                    var fbs_reader = fbs.reader();
                
                    var k = try opcodes.Operation.readFrom(fbs_reader);
                    var curr: usize = 0x00;

                    while (true) {
                        switch (k) {
                            .ifge, .ifle => |a| std.log.info((" " ** 8) ++ "{d} {s} (goto +{d}, {d})", .{curr, k, a, @intCast(i64, curr) + @intCast(i64, a)}),
                            else => std.log.info((" " ** 8) ++ "{d} {s}", .{curr, k})
                        }
                        curr += k.sizeOf();
                        k = opcodes.Operation.readFrom(fbs_reader) catch break;
                    }
                },
                .unknown => {}
            }
        }
    }

    for (class_file.attributes) |*attribute| {
        std.log.info("class attribute: '{s}'", .{attribute.getName(class_file)});
    }
}

test {
    std.testing.refAllDecls(@This());
}
