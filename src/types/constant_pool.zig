const std = @import("std");
const ClassFile = @import("ClassFile.zig");
const descriptors = @import("descriptors.zig");

pub const Tag = enum(u8) {
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

pub const ClassInfo = packed struct {
    const Self = @This();

    /// Points to a `Utf8Info`
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const RefInfo = packed struct {
    const Self = @This();

    /// Points to class or interface
    class_index: u16,
    /// Points to a `NameAndTypeInfo`
    name_and_type_index: u16,

    pub fn getClassInfo(self: Self, constant_pool: []Entry) ClassInfo {
        return constant_pool[self.class_index - 1].class;
    }

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []Entry) NameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

/// Points to a `Utf8Info`
pub const StringInfo = packed struct { string_index: u16 };

/// Represents 4-byte (32 bit) integer
pub const IntegerInfo = packed struct { bytes: u32 };

/// Represents 4-byte (32 bit) float
pub const FloatInfo = packed struct { value: u32 };

pub const LongInfo = packed struct { value: u64 };

pub const DoubleInfo = packed struct { value: u64 };

pub const NameAndTypeInfo = packed struct {
    const Self = @This();

    /// Points to a `Utf8Info` describing a unique field or method name or <init>
    name_index: u16,
    /// Points to a `Utf8Info` representing a field or method descriptor
    descriptor_index: u16,

    pub fn getName(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }

    pub fn getDescriptor(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.descriptor_index - 1].utf8.bytes;
    }
};

pub const Utf8Info = struct {
    const Self = @This();

    bytes: []u8,

    fn parse(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var length = try reader.readIntBig(u16);
        var bytes = try allocator.alloc(u8, length);
        _ = try reader.readAll(bytes);

        return Self{ .bytes = bytes };
    }
};

pub const ReferenceKind = enum(u8) { get_field = 1, get_static = 2, put_field = 3, put_static = 4, invoke_virtual = 5, invoke_static = 6, invoke_special = 7, new_invoke_special = 8, invoke_interface = 9 };

pub const MethodHandleInfo = struct {
    const Self = @This();

    reference_kind: ReferenceKind,
    /// Based on ref kind:
    /// 1, 2, 3, 4 - points to fieldref
    /// 5, 8 - points to methodref
    /// 6, 7 - points to methodref or interfacemethodref
    /// 9 - Must point to interfacemethodref
    reference_index: u16,

    fn parse(allocator: *std.mem.Allocator, reader: anytype) !Self {
        return Self{
            .reference_kind = @intToEnum(ReferenceKind, try reader.readIntBig(u8)),
            .reference_index = try reader.readIntBig(u16),
        };
    }

    pub fn getReference(self: Self, constant_pool: []Entry) Info {
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

pub const MethodTypeInfo = packed struct {
    const Self = @This();

    descriptor_index: u16,

    pub fn getDescriptor(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.descriptor_index - 1].utf8.bytes;
    }
};

pub const DynamicInfo = packed struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []Entry) NameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

pub const InvokeDynamicInfo = packed struct {
    bootstrap_method_attr_index: u16,
    name_and_type_index: u16,

    pub fn getNameAndTypeInfo(self: Self, constant_pool: []Entry) NameAndTypeInfo {
        return constant_pool[self.name_and_type_index - 1].name_and_type;
    }
};

pub const ModuleInfo = packed struct {
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const PackageInfo = packed struct {
    name_index: u16,

    pub fn getName(self: Self, constant_pool: []Entry) []const u8 {
        return constant_pool[self.name_index - 1].utf8.bytes;
    }
};

pub const Entry = union(Tag) {
    const Self = @This();

    class: ClassInfo,

    fieldref: RefInfo,
    methodref: RefInfo,
    interface_methodref: RefInfo,

    string: StringInfo,
    integer: IntegerInfo,
    float: FloatInfo,
    long: LongInfo,
    double: DoubleInfo,

    name_and_type: NameAndTypeInfo,
    utf8: Utf8Info,

    method_handle: MethodHandleInfo,
    method_type: MethodTypeInfo,

    dynamic: DynamicInfo,
    invoke_dynamic: InvokeDynamicInfo,

    module: ModuleInfo,
    package: PackageInfo,

    pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var tag = try reader.readIntBig(u8);
        inline for (@typeInfo(Tag).Enum.fields) |f, i| {
            const this_tag_value = @field(Tag, f.name);
            if (tag == @enumToInt(this_tag_value)) {
                const T = std.meta.fields(Self)[i].field_type;
                var k: T = undefined;
                if (@hasDecl(T, "parse")) k = try T.parse(allocator, reader) else {
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
