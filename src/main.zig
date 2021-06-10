const std = @import("std");
const primitives = @import("interpreter/primitives.zig");
const Interpreter = @import("interpreter/Interpreter.zig");
const ClassResolver = @import("interpreter/ClassResolver.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    var stdout = std.io.getStdOut().writer();

    var classpath = [_]std.fs.Dir{
        try std.fs.cwd().openDir("test/src", .{ .access_sub_paths = true, .iterate = true }),
        // How do I find this path, you may ask
        // 1. Find your jmods folder (for me, it's located at C:/Program Files/Java/jdk-16.0.1/jmods)
        // 2. Open `java.base.jmod` with a dearchiving tool
        // 3. Plop the content of `classes` (excluding module_info) into a new directory
        // 4. Set the string below to the path of that new directory
        try std.fs.openDirAbsolute("C:/Programming/Garbo/javastd", .{ .access_sub_paths = true, .iterate = true }),
    };
    var class_resolver = try ClassResolver.init(allocator, &classpath);

    var interpreter = Interpreter.init(allocator, &class_resolver);

    var ben = try interpreter.new("jaztest.Benjamin", .{});

    try stdout.print("\n\n\n--- OUTPUT ---\n\n\n", .{});

    try stdout.print("Ben's Awesomeness: {d}\n", .{interpreter.call("jaztest.Benjamin.main", .{})});
    try stdout.print("\n\n\n--- END OUTPUT ---\n\n\n", .{});
}

test {
    std.testing.refAllDecls(@This());
}
