const std = @import("std");
pub const opcodes = @import("types/opcodes.zig");
pub const methods = @import("types/methods.zig");
pub const ClassFile = @import("types/ClassFile.zig");
pub const descriptors = @import("types/descriptors.zig");
pub const constant_pool = @import("types/constant_pool.zig");

pub fn formatMethod(allocator: *std.mem.Allocator, class_file: ClassFile, method: *methods.MethodInfo, writer: anytype) !void {
    if (method.access_flags.public) _ = try writer.writeAll("public ");
    if (method.access_flags.private) _ = try writer.writeAll("private ");
    if (method.access_flags.protected) _ = try writer.writeAll("protected ");

    if (method.access_flags.static) _ = try writer.writeAll("static ");
    if (method.access_flags.abstract) _ = try writer.writeAll("abstract ");
    if (method.access_flags.final) _ = try writer.writeAll("final ");

    var desc = method.getDescriptor(class_file);
    var fbs = std.io.fixedBufferStream(desc);
    std.log.info("{s}", .{desc});
    var descriptor = try descriptors.parse(allocator, fbs.reader());
    try descriptor.method.return_type.humanStringify(writer);
    _ = try writer.writeAll(" ");
    _ = try writer.writeAll(method.getName(class_file));
    _ = try writer.writeAll("(");
    for (descriptor.method.parameters) |param, i| {
        try param.humanStringify(writer);
        if (i + 1 != descriptor.method.parameters.len)
        _ = try writer.writeAll(",");
    }
    _ = try writer.writeAll(")");
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var testClass = try std.fs.cwd().openFile("sample/Test.class", .{});
    defer testClass.close();

    var testReader = testClass.reader();
    var cl = try ClassFile.readFrom(allocator, testReader);
    
    std.log.info("this class: {s} {s}", .{cl.this_class.getName(cl.constant_pool), cl.access_flags});

    var w = std.ArrayList(u8).init(allocator);
    defer w.deinit();

    for (cl.constant_pool) |cp| {
        switch (cp) {
            .utf8, .name_and_type, .string => {},
            .fieldref, .methodref, .interface_methodref => |ref| {
                var nti = ref.getNameAndTypeInfo(cl.constant_pool);
                std.log.info("ref: class '{s}' name '{s} {s}'", .{ref.getClassInfo(cl.constant_pool).getName(cl.constant_pool), nti.getName(cl.constant_pool), nti.getDescriptor(cl.constant_pool)});
            },
            .class => |clz| {
                std.log.info("class: {s}", .{clz.getName(cl.constant_pool)});
            },
            .method_handle => |handle| {
                std.log.info("method handle: {s}", .{handle.getReference(cl.constant_pool)});
            },
            else => |o| std.log.info("OTHER: {s}", .{o})
        }
    }

    for (cl.fields) |*field| {
        std.log.info("field: '{s}' of type '{s}'", .{field.getName(cl), field.getDescriptor(cl)});
    }

    for (cl.methods) |*method| {
        w.shrinkRetainingCapacity(0);
        try formatMethod(allocator, cl, method, w.writer());
        std.log.info("method: {s}", .{w.items});
        for (method.attributes) |*att| {
            std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{att.getName(cl)});
            // std.log.info((" " ** 4) ++ "{s}", .{att.info});

            if (std.mem.eql(u8, att.getName(cl), "Code")) {
                var code = att.info;
                var fbs = std.io.fixedBufferStream(code);
                var fbs_reader = fbs.reader();
            
                var k = try opcodes.Operation.readFrom(fbs_reader);
                while (true) {
                    switch (k) {
                        .ldc => |params| {
                            std.log.info((" " ** 4) ++ "LDC: {s}", .{
                                cl.resolveConstant(params.index)
                            });
                        },
                        .getstatic => |params| {
                            var index = opcodes.getIndex(params);
                            var fieldref = cl.resolveConstant(index).fieldref;

                            std.log.info((" " ** 4) ++ "GET STATIC: {s} {s}", .{
                                fieldref.getClassInfo(cl.constant_pool).getName(cl.constant_pool), fieldref.getNameAndTypeInfo(cl.constant_pool).getName(cl.constant_pool)
                            });
                        },
                        .invokevirtual => |params| {
                            var index = opcodes.getIndex(params);
                            var methodref = cl.resolveConstant(index).methodref;

                            std.log.info((" " ** 4) ++ "INVOKE VIRTUAL: {s} {s}", .{
                                methodref.getClassInfo(cl.constant_pool).getName(cl.constant_pool), methodref.getNameAndTypeInfo(cl.constant_pool).getName(cl.constant_pool)
                            });
                        },
                        .invokespecial => |params| {
                            var index = opcodes.getIndex(params);
                            var methodref = cl.resolveConstant(index).methodref;

                            std.log.info((" " ** 4) ++ "INVOKE VIRTUAL: {s} {s}", .{
                                methodref.getClassInfo(cl.constant_pool).getName(cl.constant_pool), methodref.getNameAndTypeInfo(cl.constant_pool).getName(cl.constant_pool)
                            });
                        },
                        else => std.log.info((" " ** 4) ++ "{s}", .{k})
                    }
                    
                    k = opcodes.Operation.readFrom(fbs_reader) catch break;
                }
            }
        }
    }

    for (cl.attributes) |*attribute| {
        std.log.info("class attribute: '{s}'", .{attribute.getName(cl)});
    }
}

test {
    std.testing.refAllDecls(@This());
}
