//! NOTE: The documentation refers to types u1, u2, u3, u4; these are in BYTES, not BITS!!!

const std = @import("std");
const utils = @import("utils.zig");
const fields = @import("fields.zig");
const methods = @import("methods.zig");
const attributes = @import("attributes.zig");
const constant_pool_ = @import("constant_pool.zig");

const Self = @This();

pub const AccessFlags = struct {
    public: bool = false,
    final: bool = false,
    super: bool = false,
    interface: bool = false,
    abstract: bool = false,
    synthetic: bool = false,
    annotation: bool = false,
    enum_class: bool = false,
    module: bool = false,
};

minor_version: u16,
major_version: u16,
/// Constants (referenced classes, etc.)
constant_pool: []constant_pool_.Entry,
/// Is this class public, private, etc.
access_flags: AccessFlags,
/// Actual class in the ConstantPool
this_class: *const constant_pool_.ClassInfo,
/// Super class in the ConstantPool
super_class: ?*const constant_pool_.ClassInfo,
/// Interfaces this class inherits
interfaces: []constant_pool_.ClassInfo,
/// Fields this class has
fields: []fields.FieldInfo,
/// Methods the class has
methods: []methods.MethodInfo,
/// Attributes the class has
attributes: []attributes.AttributeInfo,

pub fn getConstantPoolEntry(self: Self, index: u16) constant_pool_.Entry {
    return self.constant_pool[index - 1];
}

pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !Self {
    var magic = try reader.readIntBig(u32);
    if (magic != 0xCAFEBABE) return error.BadMagicValue;

    var minor_version = try reader.readIntBig(u16);
    var major_version = try reader.readIntBig(u16);
    var constant_pool_count = try reader.readIntBig(u16);
    var constant_pool = try allocator.alloc(constant_pool_.Entry, constant_pool_count - 1);

    var cpi: usize = 0;
    while (cpi < constant_pool.len) : (cpi += 1) {
        var cp = try constant_pool_.Entry.parse(allocator, reader);
        constant_pool[cpi] = cp;
        if (cp == .double or cp == .long) {
            cpi += 1;
        }
    }

    var access_flags_u = try reader.readIntBig(u16);
    var access_flags = AccessFlags{
        .public = utils.isPresent(u16, access_flags_u, 0x0001),
        .final = utils.isPresent(u16, access_flags_u, 0x0010),
        .super = utils.isPresent(u16, access_flags_u, 0x0020),
        .interface = utils.isPresent(u16, access_flags_u, 0x0200),
        .abstract = utils.isPresent(u16, access_flags_u, 0x0400),
        .synthetic = utils.isPresent(u16, access_flags_u, 0x1000),
        .annotation = utils.isPresent(u16, access_flags_u, 0x2000),
        .enum_class = utils.isPresent(u16, access_flags_u, 0x4000),
        .module = utils.isPresent(u16, access_flags_u, 0x8000),
    };

    var this_class_u = try reader.readIntBig(u16);
    var this_class = &constant_pool[this_class_u - 1].class;

    var super_class_u = try reader.readIntBig(u16);
    var super_class = if (super_class_u == 0) null else &constant_pool[super_class_u - 1].class;

    var interfaces_count = try reader.readIntBig(u16);
    var interfaces = try allocator.alloc(constant_pool_.ClassInfo, interfaces_count);
    for (interfaces) |*i| {
        var k = try reader.readStruct(constant_pool_.ClassInfo);
        if (std.Target.current.cpu.arch.endian() == .Little) {
            inline for (std.meta.fields(constant_pool_.ClassInfo)) |f2| @field(k, f2.name) = @byteSwap(f2.field_type, @field(k, f2.name));
        }
        i.* = k;
    }

    var fields_count = try reader.readIntBig(u16);
    var fieldss = try allocator.alloc(fields.FieldInfo, fields_count);
    for (fieldss) |*f| f.* = try fields.FieldInfo.readFrom(allocator, reader);

    var methods_count = try reader.readIntBig(u16);
    var methodss = try allocator.alloc(methods.MethodInfo, methods_count);
    for (methodss) |*m| m.* = try methods.MethodInfo.readFrom(allocator, reader);

    var attributes_count = try reader.readIntBig(u16);
    var attributess = try allocator.alloc(attributes.AttributeInfo, attributes_count);
    for (attributess) |*a| a.* = try attributes.AttributeInfo.readFrom(allocator, reader);

    return Self{
        .minor_version = minor_version,
        .major_version = major_version,
        .constant_pool = constant_pool,
        .access_flags = access_flags,
        .this_class = this_class,
        .super_class = super_class,
        .interfaces = interfaces,
        .fields = fieldss,
        .methods = methodss,
        .attributes = attributess,
    };
}
