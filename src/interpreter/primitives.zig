const std = @import("std");

pub const void_value = void;

pub const byte = i8;
pub const short = i16;
pub const int = i32;
pub const long = i64;
pub const char = u16;

pub const float = f32;
pub const double = f64;

pub const reference = usize;
pub const returnAddress = usize;

pub const PrimitiveValueKind = enum(u4) {
    void,

    byte,
    short,
    int,
    long,
    char,

    float,
    double,

    reference,
    returnAddress,

    pub fn fromSingleCharRepr(c: u8) PrimitiveValueKind {
        return switch (c) {
            'i' => .int,
            'l' => .long,
            'f' => .float,
            'd' => .double,
            'a' => .reference,
            else => @panic("Invalid repr."),
        };
    }

    pub fn sizeOf(self: PrimitiveValueKind) usize {
        comptime var i: usize = 0;
        inline for (std.meta.fields(PrimitiveValue)) |f| {
            if (@enumToInt(self) == i) {
                return @sizeOf(f.type);
            }
            i += 1;
        }

        unreachable;
    }

    pub fn getType(comptime self: PrimitiveValueKind) type {
        comptime var i: usize = 0;
        inline for (std.meta.fields(PrimitiveValue)) |f| {
            if (@enumToInt(self) == i) {
                return f.type;
            }
            i += 1;
        }

        unreachable;
    }
};

pub const PrimitiveValue = union(PrimitiveValueKind) {
    void: void_value,

    byte: byte,
    short: short,
    int: int,
    long: long,
    char: char,

    float: float,
    double: double,

    reference: reference,
    returnAddress: returnAddress,

    pub fn fromNative(value: anytype) PrimitiveValue {
        return switch (@TypeOf(value)) {
            void => .void,

            byte => .{ .byte = value },
            short => .{ .short = value },
            int => .{ .int = value },
            long => .{ .long = value },
            char => .{ .char = value },

            float => .{ .float = value },
            double => .{ .double = value },

            reference => .{ .reference = value },

            else => @compileError("Invalid Java primitive type! (Is what you're inputting an int? You might want to @as or @intCast it!)"),
        };
    }

    pub fn toBool(self: *PrimitiveValue) bool {
        return self.int == 1;
    }

    pub fn isNull(self: *PrimitiveValue) bool {
        return self.reference == 0;
    }

    pub fn cast(from: PrimitiveValue, to: PrimitiveValueKind) PrimitiveValue {
        return switch (from) {
            .int => |i| switch (to) {
                .long => .{ .long = @intCast(long, i) },
                .float => .{ .float = @intToFloat(float, i) },
                .double => .{ .double = @intToFloat(double, i) },

                .byte => .{ .byte = @intCast(byte, i) },
                .char => .{ .char = @intCast(char, i) },
                .short => .{ .short = @intCast(short, i) },
                else => unreachable,
            },
            .long => |l| switch (to) {
                .int => .{ .int = @intCast(int, l) },
                .float => .{ .float = @intToFloat(float, l) },
                .double => .{ .double = @intToFloat(double, l) },
                else => unreachable,
            },
            .float => |f| switch (to) {
                .int => .{ .int = @floatToInt(int, f) },
                .long => .{ .long = @floatToInt(long, f) },
                .double => .{ .double = @floatCast(double, f) },
                else => unreachable,
            },
            .double => |d| switch (to) {
                .int => .{ .int = @floatToInt(int, d) },
                .long => .{ .long = @floatToInt(long, d) },
                .float => .{ .float = @floatCast(float, d) },
                else => unreachable,
            },
            else => unreachable,
        };
    }
};
