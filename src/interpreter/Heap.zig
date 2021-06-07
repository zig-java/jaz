const std = @import("std");
const Object = @import("Object.zig");
const array = @import("array.zig");
const ClassFile = @import("../types/ClassFile.zig");
const primitives = @import("primitives.zig");

const Heap = @This();

allocator: *std.mem.Allocator,
heap_values: std.ArrayList(HeapValue),
first_empty_index: ?usize = null,

pub const HeapValue = union(enum) { object: Object, array: array.Array, empty: void };

pub fn init(allocator: *std.mem.Allocator) Heap {
    return .{ .allocator = allocator, .heap_values = std.ArrayList(HeapValue).init(allocator) };
}

const NewHeapValue = struct { value: *HeapValue, index: usize };
fn new(self: *Heap) !NewHeapValue {
    if (self.first_empty_index) |fei| {
        var i: usize = fei;
        while (i < self.heap_values.items.len) : (i += 1) {
            if (self.heap_values.items[i] == .empty) {
                self.first_empty_index = i;
                return NewHeapValue{ .value = &self.heap_values.items[fei], .index = fei };
            }
        }

        self.first_empty_index = null;
        return NewHeapValue{ .value = &self.heap_values.items[fei], .index = fei };
    } else return NewHeapValue{ .value = try self.heap_values.addOne(), .index = self.heap_values.items.len - 1 };
}

pub fn get(self: *Heap, reference: usize) *HeapValue {
    return &self.heap_values.items[reference];
}

pub fn newObject(self: *Heap, class_file: ClassFile) !usize {
    var obj = Object.init(self.allocator, class_file);
    var n = try self.new();
    n.value.* = .{ .object = obj };
    return n.index;
}

pub fn getObject(self: *Heap, reference: usize) *Object {
    return &self.heap_values.items[reference].object;
}

pub fn newArray(self: *Heap, kind: array.ArrayKind, size: primitives.int) !usize {
    var arr = try array.Array.init(self.allocator, kind, size);
    var n = try self.new();
    n.value.* = .{ .array = arr };
    return n.index;
}

pub fn getArray(self: *Heap, reference: usize) *array.Array {
    return &self.heap_values.items[reference].array;
}

pub fn free(self: *Heap, reference: usize) void {
    switch (self.heap_values.items[reference]) {
        .array => |arr| {
            arr.deinit();
        },
        .empty => unreachable,
    }

    self.heap_values.items[reference] = .empty;
    if (self.first_empty_index) |i| {
        if (reference < i) self.first_empty_index = reference;
    } else {
        self.first_empty_index = reference;
    }
}
