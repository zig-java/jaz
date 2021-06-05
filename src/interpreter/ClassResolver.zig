//! Resolves classes 😎

const std = @import("std");
const ClassFile = @import("../types/ClassFile.zig");

const ClassResolver = @This();

allocator: *std.mem.Allocator,
classpath_dirs: []std.fs.Dir,
hash_map: std.StringHashMap(ClassFile),

pub fn init(allocator: *std.mem.Allocator, classpath_dirs: []std.fs.Dir) !ClassResolver {
    return ClassResolver{ .allocator = allocator, .classpath_dirs = classpath_dirs, .hash_map = std.StringHashMap(ClassFile).init(allocator) };
}

/// Not recommended!
pub fn initWithPaths(allocator: *std.mem.Allocator, classpath: [][]const u8) !ClassResolver {
    var classpath_dirs = try allocator.alloc(std.fs.Dir, classpath.len);
    for (classpath) |cp, i| {
        classpath_dirs[i] = try std.fs.openDirAbsolute(cp, .{ .access_sub_paths = true, .iterate = true });
    }

    return ClassResolver{ .allocator = allocator, .classpath_dirs = classpath_dirs, .hash_map = std.StringHashMap(ClassFile).init(allocator) };
}

pub fn resolve(self: *ClassResolver, path: []const u8) !ClassFile {
    if (self.hash_map.get(path)) |cf| return cf;

    var sub = std.ArrayList(std.fs.Dir).init(self.allocator);

    var parts = std.mem.split(path, ".");
    var i: usize = 0;
    var m = std.mem.count(u8, path, ".");

    while (parts.next()) |part| {
        for (self.classpath_dirs) |d, j| {
            var subdir = d.openDir(part, .{ .access_sub_paths = true, .iterate = true }) catch continue;
            try sub.append(subdir);
        }

        break;
    }

    while (parts.next()) |part| : (i += 1) {
        for (sub.items) |*d, j| {
            if (i + 1 == m) {
                // Indicates that this is the last part of the Java path thang; openFile, not dir

                var full_name = try std.mem.concat(self.allocator, u8, &.{ part, ".class" });
                defer self.allocator.free(full_name);

                var testClass = try d.openFile(full_name, .{});
                defer testClass.close();

                var testReader = testClass.reader();
                var class_file = try ClassFile.readFrom(self.allocator, testReader);
                try self.hash_map.put(path, class_file);

                return class_file;
            } else {
                // std.log.info("{s}", .{part});
                var subdir = d.openDir(part, .{ .access_sub_paths = true, .iterate = true }) catch {
                    d.close();
                    _ = sub.orderedRemove(j);
                    continue;
                };

                _ = sub.orderedRemove(j);
                try sub.append(subdir);
            }
        }
    }

    for (sub.items) |*d| d.close();

    return error.NotFound;
}

pub fn deinit(self: ClassResolver) void {
    for (self.classpath_dirs) |d| d.close();
    self.allocator.free(self.classpath_dirs);
}
