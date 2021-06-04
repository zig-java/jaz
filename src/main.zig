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

    var args = [_]primitives.PrimitiveValue{ .{ .float = 8 }, .{ .float = 7 } };
    std.log.info("Value = {d}", .{
        (try interpreter.interpret(allocator, class_file, "add", &args)).int
    });
}

test {
    std.testing.refAllDecls(@This());
}
