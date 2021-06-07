const std = @import("std");
const utils = @import("utils.zig");
const primitives = @import("primitives.zig");
const ClassFile = @import("../types/ClassFile.zig");

const Object = @This();

class_file: ClassFile,
allocator: *std.mem.Allocator,
// TODO: Optimize this into a []u8 where I can dump data based on its predetermined size; Java is typed for a reason...
fields: std.StringHashMap(primitives.PrimitiveValue),

pub fn init(allocator: *std.mem.Allocator, class_file: ClassFile) Object {
    return .{
        .class_file = class_file,
        .allocator = allocator,
        .fields = std.StringHashMap(primitives.PrimitiveValue).init(allocator),
    };
}

/// Caller owns memory; `self.allocator.free(class_name)`.
pub fn getClassName(self: Object) ![]const u8 {
    var class_name_slashes = self.class_file.this_class.getName(self.class_file.constant_pool);
    return try utils.classToDots(self.allocator, class_name_slashes);
}

pub fn deinit(self: *Object) void {
    self.fields.deinit();
}

pub fn setField(self: *Object, name: []const u8, value: primitives.PrimitiveValue) !void {
    try self.fields.put(name, value);
}

pub fn getField(self: *Object, name: []const u8) ?primitives.PrimitiveValue {
    return self.fields.get(name);
}
