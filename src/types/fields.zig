const std = @import("std");
const utils = @import("utils.zig");
const attributes = @import("attributes.zig");
const ClassFile = @import("ClassFile.zig");

pub const FieldAccessFlags = struct {
    public: bool = false,
    private: bool = false,
    protected: bool = false,
    static: bool = false,
    final: bool = false,
    @"volatile": bool = false,
    transient: bool = false,
    synthetic: bool = false,
    enum_member: bool = false,
};

pub const FieldInfo = struct {
    const Self = @This();

    access_flags: FieldAccessFlags,
    name_index: u16,
    descriptor_index: u16,
    attributes: []attributes.AttributeInfo,

    pub fn getName(self: *Self, class_file: ClassFile) []const u8 {
        return class_file.resolveConstant(self.name_index).utf8.bytes;
    }

    pub fn getDescriptor(self: *Self, class_file: ClassFile) []const u8 {
        return class_file.resolveConstant(self.descriptor_index).utf8.bytes;
    }

    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var access_flags_u = try reader.readIntBig(u16);
        var name_index = try reader.readIntBig(u16);
        var descriptor_index = try reader.readIntBig(u16);

        var att_count = try reader.readIntBig(u16);
        var att = try allocator.alloc(attributes.AttributeInfo, att_count);
        for (att) |*a| a.* = try attributes.AttributeInfo.readFrom(allocator, reader);

        return Self{
            .access_flags = .{
                .public = utils.isPresent(u16, access_flags_u, 0x0001),
                .private = utils.isPresent(u16, access_flags_u, 0x0002),
                .protected = utils.isPresent(u16, access_flags_u, 0x0004),
                .static = utils.isPresent(u16, access_flags_u, 0x0008),
                .final = utils.isPresent(u16, access_flags_u, 0x0010),
                .@"volatile" = utils.isPresent(u16, access_flags_u, 0x0040),
                .transient = utils.isPresent(u16, access_flags_u, 0x0080),
                .synthetic = utils.isPresent(u16, access_flags_u, 0x1000),
                .enum_member = utils.isPresent(u16, access_flags_u, 0x4000),
            },
            .name_index = name_index,
            .descriptor_index = descriptor_index,
            .attributes = att,
        };
    }
};
