const std = @import("std");
const Object = @import("Object.zig");
const Array = @import("Array.zig");
const primitives = @import("primitives.zig");

const Heap = @This();

allocator: *std.mem.Allocator,
heap_values: std.ArrayList(HeapValue),

pub const HeapValue = union(enum) { object: Object, array: Array, empty: void };

pub fn init(allocator: *std.mem.Allocator) Heap {
    return .{ .allocator = allocator, .heap_values = std.ArrayList(HeapValue).init(allocator) };
}

pub fn newObject(self: *Heap) !usize {
    var obj = Object.init(self.allocator);
    try self.heap_values.append(.{ .object = obj });
    return self.heap_values.items.len - 1;
}

pub fn getObject(self: *Heap, reference: usize) *Object {
    return &self.heap_values.items[reference].object;
}

pub fn newArray(self: *Heap, size: primitives.int) !usize {
    var arr = try Array.init(self.allocator, size);
    try self.heap_values.append(.{ .array = arr });
    return self.heap_values.items.len - 1;
}

pub fn getArray(self: *Heap, reference: usize) *Array {
    return &self.heap_values.items[reference].array;
}
