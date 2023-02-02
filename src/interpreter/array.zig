const std = @import("std");
const primitives = @import("primitives.zig");

pub const ArrayKind = enum { byte, short, int, long, char, float, double, reference };
pub const Array = union(ArrayKind) {
    byte: ArrayOf(primitives.byte),
    short: ArrayOf(primitives.short),
    int: ArrayOf(primitives.int),
    long: ArrayOf(primitives.long),
    char: ArrayOf(primitives.char),

    float: ArrayOf(primitives.float),
    double: ArrayOf(primitives.double),

    reference: ArrayOf(primitives.reference),

    pub fn init(allocator: std.mem.Allocator, kind: ArrayKind, count: primitives.int) !Array {
        inline for (std.meta.fields(ArrayKind)) |field| {
            if (@enumToInt(kind) == field.value) {
                return @unionInit(Array, field.name, try ArrayOf(@field(primitives, field.name)).init(allocator, count));
            }
        }

        unreachable;
    }

    pub fn set(self: Array, index: primitives.int, value: primitives.PrimitiveValue) !void {
        inline for (std.meta.fields(ArrayKind)) |field| {
            if (@enumToInt(std.meta.activeTag(self)) == field.value) {
                return @field(self, field.name).set(index, @field(value, field.name));
            }
        }

        unreachable;
    }

    pub fn get(self: Array, index: primitives.int) !primitives.PrimitiveValue {
        inline for (std.meta.fields(ArrayKind)) |field| {
            if (@enumToInt(std.meta.activeTag(self)) == field.value) {
                return @unionInit(primitives.PrimitiveValue, field.name, try @field(self, field.name).get(index));
            }
        }

        unreachable;
    }

    pub fn length(self: Array) primitives.int {
        inline for (std.meta.fields(ArrayKind)) |field| {
            if (@enumToInt(std.meta.activeTag(self)) == field.value) {
                return @field(self, field.name).length();
            }
        }

        unreachable;
    }
};

/// Create an array of type `T`. T should be a primitive.
pub fn ArrayOf(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []T,

        pub fn init(allocator: std.mem.Allocator, count: primitives.int) !Self {
            if (count < 0) return error.NegativeArraySize;

            var slice = try allocator.alloc(T, @intCast(usize, try std.math.absInt(count)));
            return Self{ .slice = slice };
        }

        pub fn set(self: Self, index: primitives.int, value: T) !void {
            if (index < 0) return error.NegativeIndex;
            self.slice[@intCast(usize, try std.math.absInt(index))] = value;
        }

        pub fn get(self: Self, index: primitives.int) !T {
            if (index < 0) return error.NegativeIndex;
            return self.slice[@intCast(usize, try std.math.absInt(index))];
        }

        pub fn length(self: Self) primitives.int {
            return @intCast(primitives.int, self.slice.len);
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.slice);
        }
    };
}
