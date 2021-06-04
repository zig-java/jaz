const std = @import("std");
const Interpreter = @import("interpreter/Interpreter.zig");
const ClassResolver = @import("interpreter/ClassResolver.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var cp = [_][]const u8{"C:/Programming/Zig/zaj/test/src"};
    var class_resolver = try ClassResolver.init(allocator, &cp);
    // try class_resolver.resolve("sample.Test.test");
    std.log.info("{s}", .{try class_resolver.resolve("jaztest.Test")});
    // var interpreter = Interpreter.init(allocator, class_resolver);
    // var s = interpreter.getMethod("sample.Test.test", .{
    //     .param_types = &[_].{},
    //     .return_type = void,
    // });

    // s.call(.{});
}

test {
    std.testing.refAllDecls(@This());
}
