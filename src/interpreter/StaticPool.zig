const std = @import("std");
const Object = @import("Object.zig");
const ClassFile = @import("../types/ClassFile.zig");

const StaticPool = @This();

allocator: *std.mem.Allocator,
pool: std.StringHashMap(Object),

pub fn init(allocator: *std.mem.Allocator) StaticPool {
    return .{ .allocator = allocator, .pool = std.StringHashMap(Object).init(allocator) };
}

pub fn hasClass(self: *StaticPool, name: []const u8) bool {
    return self.pool.get(name) != null;
}

pub fn getClass(self: *StaticPool, name: []const u8) ?*Object {
    return if (self.pool.get(name)) |*o| o else null;
}

pub fn addClass(self: *StaticPool, name: []const u8, class_file: ClassFile) !void {
    // try self.pool.put(name, try Object.initStatic(self.allocator, class_file));
}
