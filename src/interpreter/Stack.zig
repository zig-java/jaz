const std = @import("std");
const primitives = @import("primitives.zig");

const Self = @This();

array_list: std.ArrayList(primitives.PrimitiveValue),

pub fn init(allocator: *std.mem.Allocator) Self {
    return .{
        .array_list = std.ArrayList(primitives.PrimitiveValue).init(allocator)
    };
}

pub fn pop(self: *Self) primitives.PrimitiveValue {
    return self.array_list.pop();
}

pub fn popToStruct(self: *Self, comptime T: type) T {
    var res: T = undefined;
    comptime var i: usize = 0;
    inline while (i < std.meta.fields(T).len) : (i += 1) {
        comptime var field = std.meta.fields(T)[std.meta.fields(T).len - 1 - i];
        @field(res, field.name) = switch (field.field_type) {
            primitives.@"null" => self.pop().@"null",

            primitives.byte => self.pop().byte,
            primitives.int => self.pop().int,
            primitives.long => self.pop().long,
            primitives.char => self.pop().char,
            primitives.boolean => self.pop().boolean,

            primitives.float => self.pop().float,
            primitives.double => self.pop().double,

            else => @compileLog("Type needs to be primitive!")
        };
    }
    return res;
}
    
pub fn push(self: *Self, value: primitives.PrimitiveValue) !void {
    try self.array_list.append(value);
}

pub fn deinit(self: *Self) void {
    self.array_list.deinit();
}
