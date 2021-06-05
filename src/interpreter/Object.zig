const std = @import("std");
const primitives = @import("primitives.zig");
const ClassFile = @import("../typs/ClassFile.zig");

const Object = @This();

allocator: *std.mem.Allocator,
fields: std.StringHashMap(primitives.PrimitiveValue),

pub fn init(allocator: *std.mem.Allocator) Object {
    return .{
        .allocator = allocator,
        .fields = std.StringHashMap(primitives.PrimitiveValue).init(allocator),
    };
}

pub fn deinit(self: *Object) void {
    self.fields.deinit();
}

pub fn setField(self: *Object, name: []const u8, value: primitives.PrimitiveValue) !void {
    self.fields.put(name, value);
}

pub fn getField(self: *Object, name: []const u8) primitives.PrimitiveValue {
    return self.fields.get(name);
}
