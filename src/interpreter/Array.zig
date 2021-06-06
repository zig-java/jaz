const std = @import("std");
const primitives = @import("primitives.zig");
const ClassFile = @import("../typs/ClassFile.zig");

const Array = @This();

slice: []primitives.PrimitiveValue,

pub fn init(allocator: *std.mem.Allocator, count: primitives.int) !Array {
    if (count < 0) return error.NegativeArraySize;

    var slice = try allocator.alloc(primitives.PrimitiveValue, @intCast(usize, try std.math.absInt(count)));
    return Array{ .slice = slice };
}

pub fn set(self: Array, index: primitives.int, value: primitives.PrimitiveValue) !void {
    if (index < 0) return error.NegativeIndex;
    self.slice[@intCast(usize, try std.math.absInt(index))] = value;
}

pub fn get(self: Array, index: primitives.int) !primitives.PrimitiveValue {
    if (index < 0) return error.NegativeIndex;
    return self.slice[@intCast(usize, try std.math.absInt(index))];
}

pub fn length(self: Array) primitives.int {
    return @intCast(primitives.int, self.slice.len);
}
