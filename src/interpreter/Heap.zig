const std = @import("std");
const Object = @import("Object.zig");
const array = @import("array.zig");
const primitives = @import("primitives.zig");
const ClassResolver = @import("ClassResolver.zig");

const cf = @import("cf");
const ClassFile = cf.ClassFile;

const Heap = @This();

allocator: std.mem.Allocator,
heap_values: std.ArrayList(HeapValue),
first_empty_index: ?usize = null,

pub const HeapValue = union(enum) { object: Object, array: array.Array, empty: void };

pub fn init(allocator: std.mem.Allocator) Heap {
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
    if (reference == 0) @panic("Attempt to use null reference!");
    return &self.heap_values.items[reference - 1];
}

pub fn newObject(self: *Heap, class_file: *const ClassFile, class_resolver: *ClassResolver) !usize {
    var obj = try Object.initNonStatic(self.allocator, class_file, class_resolver);
    var n = try self.new();
    n.value.* = .{ .object = obj };
    return n.index + 1;
}

pub fn getObject(self: *Heap, reference: usize) *Object {
    return &self.heap_values.items[reference - 1].object;
}

pub fn newArray(self: *Heap, kind: array.ArrayKind, size: primitives.int) !usize {
    var arr = try array.Array.init(self.allocator, kind, size);
    var n = try self.new();
    n.value.* = .{ .array = arr };
    return n.index + 1;
}

pub fn getArray(self: *Heap, reference: usize) *array.Array {
    return &self.heap_values.items[reference - 1].array;
}

pub fn free(self: *Heap, reference: usize) void {
    switch (self.heap_values.items[reference - 1]) {
        .array => |arr| {
            arr.deinit();
        },
        .empty => unreachable,
    }

    self.heap_values.items[reference - 1] = .empty;
    if (self.first_empty_index) |i| {
        if (reference - 1 < i) self.first_empty_index = reference - 1;
    } else {
        self.first_empty_index = reference - 1;
    }
}
