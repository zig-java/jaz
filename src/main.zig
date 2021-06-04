const std = @import("std");
const interpreter = @import("interpreter/interpreter.zig");
const ClassFile = @import("types/ClassFile.zig");
const primitives = @import("interpreter/primitives.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var testClass = try std.fs.cwd().openFile("sample/Test.class", .{});
    defer testClass.close();

    var testReader = testClass.reader();
    var class_file = try ClassFile.readFrom(allocator, testReader);

    var args = [_]primitives.PrimitiveValue{ .{ .int = 234 }, .{ .int = 23456 } };
    std.log.info("Value = {s}", .{
        try interpreter.interpret(allocator, class_file, "sign", &args)
    });
}

test {
    std.testing.refAllDecls(@This());
}
