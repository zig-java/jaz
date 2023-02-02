//! Resolves classes 😎

const std = @import("std");
const cf = @import("cf");
const ClassFile = cf.ClassFile;

const ClassResolver = @This();

allocator: std.mem.Allocator,
/// Transforms "a/b/c" -> "/java/path/a/b/c.class"
absolute_path_map: std.StringHashMapUnmanaged([]const u8) = .{},
/// Transforms "a/b/c" -> ClassFile(...)
class_file_map: std.StringHashMapUnmanaged(*ClassFile) = .{},

pub fn init(allocator: std.mem.Allocator, classpath_dirs: [][]const u8) !ClassResolver {
    var class_resolver = ClassResolver{ .allocator = allocator };

    for (classpath_dirs) |path| {
        try populateAbsolutePathMap(&class_resolver, path, "");
    }

    return class_resolver;
}

fn populateAbsolutePathMap(
    resolver: *ClassResolver,
    path: []const u8,
    slashes: []const u8,
) !void {
    var iterable = try std.fs.openIterableDirAbsolute(path, .{});
    defer iterable.close();

    var iterator = iterable.iterate();

    while (try iterator.next()) |it| {
        const sub_path = try std.fs.path.join(resolver.allocator, &.{ path, it.name });
        const sub_slashes = if (slashes.len == 0) it.name else try std.mem.join(resolver.allocator, "/", &.{
            slashes,
            if (it.kind == .File and std.mem.endsWith(u8, it.name, ".class"))
                it.name[0 .. it.name.len - 6]
            else
                it.name[0..it.name.len],
        });

        switch (it.kind) {
            .Directory => {
                try resolver.populateAbsolutePathMap(sub_path, sub_slashes);
            },
            .File => {
                try resolver.absolute_path_map.put(resolver.allocator, sub_slashes, sub_path);
            },
            else => {
                resolver.allocator.free(sub_slashes);
                std.log.warn("Unknown iterator entry: {any}", .{it});
            },
        }
    }
}

/// Resolve Class from "java.abc.def" notations
pub fn resolve(resolver: *ClassResolver, slashes: []const u8) !?*ClassFile {
    return resolver.class_file_map.get(slashes) orelse {
        var file = try std.fs.openFileAbsolute(resolver.absolute_path_map.get(slashes) orelse return null, .{});
        defer file.close();

        var class_file = try resolver.allocator.create(ClassFile);
        class_file.* = try ClassFile.decode(resolver.allocator, file.reader());

        try resolver.class_file_map.put(
            resolver.allocator,
            try resolver.allocator.dupe(u8, slashes),
            class_file,
        );

        return class_file;
    };
}

pub fn deinit(self: ClassResolver) void {
    for (self.classpath_dirs) |d| d.close();
    self.allocator.free(self.classpath_dirs);
}
