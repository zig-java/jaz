const std = @import("std");
const Object = @import("Object.zig");

const StaticPool = @This();

pool: std.StringHashMap(Object),

pub fn init(allocator: *std.mem.Allocator) StaticPool {
    return .{ .pool = std.StringHashMap(Object).init(allocator) };
}

pub fn hasClass(self: *StaticPool, name: []const u8) bool {
    return self.pool.get(name) != null;
}

pub fn getClass(self: *StaticPool, name: []const u8) !*Object {
    var entry = try self.pool.getOrPut(name);
    return entry.value_ptr;
}
