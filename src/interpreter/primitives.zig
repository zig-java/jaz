pub const @"null" = void;
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

pub const PrimitiveValue = union(enum) {
    @"null": @"null",
    @"void": void_value,

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
            void => .@"void",

            byte => .{ .byte = value },
            short => .{ .short = value },
            int => .{ .int = value },
            long => .{ .long = value },
            char => .{ .char = value },

            float => .{ .float = value },
            double => .{ .double = value },

            else => @compileError("Invalid Java primitive type! (Is what you're inputting an int? You might want to @as or @intCast it!)"),
        };
    }
};
