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
};
