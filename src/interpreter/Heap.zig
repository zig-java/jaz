const std = @import("std");
const Object = @import("Object.zig");

const Heap = @This();

allocator: *std.mem.Allocator,
objects: std.ArrayList(?Object),

pub fn init(allocator: *std.mem.Allocator) Heap {
    return .{ .allocator = allocator, .objects = std.ArrayList(?Object).init(allocator) };
}

pub fn newObject(self: *Heap) !usize {
    var obj = Object.init(self.allocator);
    try self.objects.append(obj);
    return self.objects.items.len - 1;
}
