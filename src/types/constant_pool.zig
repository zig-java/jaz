const std = @import("std");
const ClassFile = @import("ClassFile.zig");
const descriptors = @import("descriptors.zig");

pub const ConstantPoolTag = enum(u8) {
    class = 7,
    fieldref = 9,
    methodref = 10,
    interface_methodref = 11,
    string = 8,
    integer = 3,
    float = 4,
    long = 5,
    double = 6,
    name_and_type = 12,
    utf8 = 1,
    method_handle = 15,
    method_type = 16,
    dynamic = 17,
    invoke_dynamic = 18,
    module = 19,
    package = 20,
};

pub const ConstantPoolClassInfo = packed struct {
    const Self = @This();

    /// Points to a `ConstantPoolUtf8Info`
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const ConstantPoolRefInfo = packed struct {
    const Self = @This();

    /// Points to class or interface
    class_index: u16,
    /// Points to a `ConstantPoolNameAndTypeInfo`
    name_and_type_index: u16,

    pub fn getClassInfo(self: Self, constant_pool: []ConstantPoolInfo) ConstantPoolClassInfo {
        return constant_pool[self.class_index - 1].class;
    }

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []ConstantPoolInfo) ConstantPoolNameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

/// Points to a `ConstantPoolUtf8Info`
pub const ConstantPoolStringInfo = packed struct { string_index: u16 };

/// Represents 4-byte (32 bit) integer
pub const ConstantPoolIntegerInfo = packed struct { bytes: u32 };

/// Represents 4-byte (32 bit) float
pub const ConstantPoolFloatInfo = packed struct { bytes: u32 };

pub const ConstantPoolLongInfo = packed struct {
// high_bytes: u32,
// low_bytes: u32
bingus: u64 };

pub const ConstantPoolDoubleInfo = packed struct { high_bytes: u32, low_bytes: u32 };

pub const ConstantPoolNameAndTypeInfo = packed struct {
    const Self = @This();

    /// Points to a `ConstantPoolUtf8Info` describing a unique field or method name or <init>
    name_index: u16,
    /// Points to a `ConstantPoolUtf8Info` representing a field or method descriptor
    descriptor_index: u16,

    pub fn getName(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }

    pub fn getDescriptor(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.descriptor_index - 1].utf8.bytes;
    }
};

pub const ConstantPoolUtf8Info = struct {
    const Self = @This();

    bytes: []u8,

    fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var length = try reader.readIntBig(u16);
        var bytes = try allocator.alloc(u8, length);
        _ = try reader.readAll(bytes);

        return Self{ .bytes = bytes };
    }
};

pub const ConstantPoolReferenceKind = enum(u8) { get_field = 1, get_static = 2, put_field = 3, put_static = 4, invoke_virtual = 5, invoke_static = 6, invoke_special = 7, new_invoke_special = 8, invoke_interface = 9 };

pub const ConstantPoolMethodHandleInfo = struct {
    const Self = @This();

    reference_kind: ConstantPoolReferenceKind,
    /// Based on ref kind:
    /// 1, 2, 3, 4 - points to fieldref
    /// 5, 8 - points to methodref
    /// 6, 7 - points to methodref or interfacemethodref
    /// 9 - Must point to interfacemethodref
    reference_index: u16,

    fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        return Self{
            .reference_kind = @intToEnum(ConstantPoolReferenceKind, try reader.readIntBig(u8)),
            .reference_index = try reader.readIntBig(u16),
        };
    }

    pub fn getReference(self: Self, constant_pool: []ConstantPoolInfo) ConstantPoolInfo {
        var ref = constant_pool[self.reference_index - 1];
        switch (self.reference_kind) {
            .get_field, .get_static, .put_field, .put_static => std.debug.assert(std.meta.activeTag(ref) == .fieldref),

            .invoke_virtual, .new_invoke_special => std.debug.assert(std.meta.activeTag(ref) == .methodref),

            .invoke_static, .invoke_special => std.debug.assert(std.meta.activeTag(ref) == .methodref or std.meta.activeTag(ref) == .interface_methodref),

            .invoke_interface => std.debug.assert(std.meta.activeTag(ref) == .interface_methodref),
        }
        return ref;
    }
};

pub const ConstantPoolMethodTypeInfo = packed struct {
    const Self = @This();

    descriptor_index: u16,

    pub fn getDescriptor(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.descriptor_index - 1].utf8.bytes;
    }
};

pub const ConstantPoolDynamicInfo = packed struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []ConstantPoolInfo) ConstantPoolNameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

pub const ConstantPoolInvokeDynamicInfo = packed struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []ConstantPoolInfo) ConstantPoolNameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

pub const ConstantPoolModuleInfo = packed struct {
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const ConstantPoolPackageInfo = packed struct {
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []ConstantPoolInfo) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const ConstantPoolInfo = union(ConstantPoolTag) {
    const Self = @This();

    class: ConstantPoolClassInfo,

    fieldref: ConstantPoolRefInfo,
    methodref: ConstantPoolRefInfo,
    interface_methodref: ConstantPoolRefInfo,

    string: ConstantPoolStringInfo,
    integer: ConstantPoolIntegerInfo,
    float: ConstantPoolFloatInfo,
    long: ConstantPoolLongInfo,
    double: ConstantPoolDoubleInfo,

    name_and_type: ConstantPoolNameAndTypeInfo,
    utf8: ConstantPoolUtf8Info,

    method_handle: ConstantPoolMethodHandleInfo,
    method_type: ConstantPoolMethodTypeInfo,

    dynamic: ConstantPoolDynamicInfo,
    invoke_dynamic: ConstantPoolInvokeDynamicInfo,

    module: ConstantPoolModuleInfo,
    package: ConstantPoolPackageInfo,

    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var tag = try reader.readIntBig(u8);
        inline for (@typeInfo(ConstantPoolTag).Enum.fields) |f, i| {
            const this_tag_value = @field(ConstantPoolTag, f.name);
            if (tag == @enumToInt(this_tag_value)) {
                const T = std.meta.fields(Self)[i].field_type;
                var k: T = undefined;
                if (@hasDecl(T, "readFrom")) k = try T.readFrom(allocator, reader) else {
                    k = try reader.readStruct(T);
                    if (std.Target.current.cpu.arch.endian() == .Little) {
                        inline for (std.meta.fields(T)) |f2| @field(k, f2.name) = @byteSwap(f2.field_type, @field(k, f2.name));
                    }
                }

                return @unionInit(Self, f.name, k);
            }
        }
        unreachable;
    }
};
