const std = @import("std");
const opcodes = @import("types/opcodes.zig");
const ClassFile = @import("types/ClassFile.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var testClass = try std.fs.cwd().openFile("sample/Test.class", .{});
    defer testClass.close();

    var testReader = testClass.reader();
    var cl = try ClassFile.readFrom(allocator, testReader);
    
    std.log.info("this class: {s}", .{cl.this_class.resolveName(cl.constant_pool).bytes});

    for (cl.constant_pool) |cp| {
        switch (cp) {
            .utf8, .name_and_type, .string => {},
            .fieldref, .methodref, .interface_methodref => |ref| {
                var nti = ref.resolveNameAndTypeInfo(cl.constant_pool);
                std.log.info("ref: class '{s}' name '{s} {s}'", .{ref.resolveClassInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes, nti.resolveName(cl.constant_pool).bytes, nti.resolveDescriptor(cl.constant_pool).bytes});
            },
            .class => |clz| {
                std.log.info("class: {s}", .{clz.resolveName(cl.constant_pool).bytes});
            },
            .method_handle => |handle| {
                std.log.info("method handle: {s}", .{handle.resolveReference(cl.constant_pool)});
            },
            else => |o| std.log.info("OTHER: {s}", .{o})
        }
    }

    for (cl.fields) |*field| {
        std.log.info("field: '{s}' of type '{s}'", .{field.getName(cl), field.getDescriptor(cl)});
    }

    for (cl.methods) |*method| {
        std.log.info("method: '{s}' of type '{s}'", .{method.getName(cl), method.getDescriptor(cl)});
        for (method.attributes) |*att| {
            std.log.info((" " ** 4) ++ "method attribute: '{s}'", .{att.getName(cl)});
            // std.log.info((" " ** 4) ++ "{s}", .{att.info});

            if (std.mem.eql(u8, att.getName(cl), "Code")) {
                var code = att.info;
                var fbs = std.io.fixedBufferStream(code);
                var fbs_reader = fbs.reader();
            
                var k = try opcodes.Operation.readFrom(fbs_reader);
                while (true) {
                    switch (k.opcode) {
                        .ldc => {
                            var params = k.params.ldc;

                            std.log.info((" " ** 4) ++ "LDC: {s}", .{
                                cl.resolveConstant(params.index)
                            });
                        },
                        .getstatic => {
                            var params = k.params.getstatic;
                            var index = opcodes.indexFromTwo(params.indexbyte1, params.indexbyte2);
                            var fieldref = cl.resolveConstant(index).fieldref;

                            std.log.info((" " ** 4) ++ "GET STATIC: {s} {s}", .{
                                fieldref.resolveClassInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes, fieldref.resolveNameAndTypeInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes
                            });
                        },
                        .invokevirtual => {
                            var params = k.params.invokevirtual;
                            var index = opcodes.indexFromTwo(params.indexbyte1, params.indexbyte2);
                            var methodref = cl.resolveConstant(index).methodref;

                            std.log.info((" " ** 4) ++ "INVOKE VIRTUAL: {s} {s}", .{
                                methodref.resolveClassInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes, methodref.resolveNameAndTypeInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes
                            });
                        },
                        .invokespecial => {
                            var params = k.params.invokespecial;
                            var index = opcodes.indexFromTwo(params.indexbyte1, params.indexbyte2);
                            var methodref = cl.resolveConstant(index).methodref;

                            std.log.info((" " ** 4) ++ "INVOKE VIRTUAL: {s} {s}", .{
                                methodref.resolveClassInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes, methodref.resolveNameAndTypeInfo(cl.constant_pool).resolveName(cl.constant_pool).bytes
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
