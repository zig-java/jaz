const std = @import("std");
const ClassFile = @import("ClassFile.zig");

pub const AttributeInfo = struct {
    const Self = @This();

    attribute_name_index: u16,
    info: []u8,

    pub fn getName(self: *Self, class_file: ClassFile) []const u8 {
        return class_file.resolveConstant(self.attribute_name_index).utf8.bytes;
    }
    
    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var attribute_name_index = try reader.readIntBig(u16);
        var attribute_length = try reader.readIntBig(u32);
        
        var info = try allocator.alloc(u8, attribute_length);
        _ = try reader.readAll(info);

        return Self{
            .attribute_name_index = attribute_name_index,
            .info = info
        };
    }
};
