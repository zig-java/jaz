const std = @import("std");
const utils = @import("utils.zig");
const primitives = @import("primitives.zig");
const descriptors = @import("../types/descriptors.zig");
const ClassFile = @import("../types/ClassFile.zig");
const ClassResolver = @import("ClassResolver.zig");

const Object = @This();

pub const ObjectFieldInfo = struct { hash: u64, kind: primitives.PrimitiveValueKind };

allocator: *std.mem.Allocator,
class_file: *ClassFile,
field_info: []ObjectFieldInfo,
field_data_pool: []u8,

// TODO: Store field info somewhere once generated!

pub fn genNonStaticFieldInfo(allocator: *std.mem.Allocator, arr: *std.ArrayList(ObjectFieldInfo), class_file: *ClassFile, class_resolver: *ClassResolver) anyerror!void {
    if (class_file.super_class) |super| {
        var class_name_slashes = super.getName(class_file.constant_pool);
        var class_name = try utils.classToDots(allocator, class_name_slashes);
        defer allocator.free(class_name);

        try genNonStaticFieldInfo(allocator, arr, try class_resolver.resolve(class_name), class_resolver);
    }

    for (class_file.fields) |*field| {
        if (field.access_flags.static) continue;

        var desc = try descriptors.parseString(allocator, field.getDescriptor(class_file));
        defer desc.deinit(allocator);

        try arr.append(.{
            .hash = std.hash.Wyhash.hash(arr.items.len, field.getName(class_file)),
            .kind = switch (desc.*) {
                .byte => .byte,
                .char => .char,

                .int, .boolean => .int,
                .long => .long,
                .short => .short,

                .float => .float,
                .double => .double,

                .object, .array => .reference,

                else => unreachable,
            },
        });
    }
}

pub fn initNonStatic(allocator: *std.mem.Allocator, class_file: *ClassFile, class_resolver: *ClassResolver) !Object {
    var arr = std.ArrayList(ObjectFieldInfo).init(allocator);
    try genNonStaticFieldInfo(allocator, &arr, class_file, class_resolver);
    return init(allocator, class_file, arr.toOwnedSlice());
}

pub fn genStaticFieldInfo(allocator: *std.mem.Allocator, arr: *std.ArrayList(ObjectFieldInfo), class_file: ClassFile) anyerror!void {
    for (class_file.fields) |*field| {
        if (!field.access_flags.static) continue;

        var desc = try descriptors.parseString(allocator, field.getDescriptor(class_file));
        defer desc.deinit(allocator);

        try arr.append(.{
            .hash = std.hash.Wyhash.hash(arr.items.len, field.getName(class_file)),
            .kind = switch (desc.*) {
                .byte => .byte,
                .char => .char,

                .int, .boolean => .int,
                .long => .long,
                .short => .short,

                .float => .float,
                .double => .double,

                .object, .array => .reference,

                else => unreachable,
            },
        });
    }
}

pub fn initStatic(allocator: *std.mem.Allocator, class_file: ClassFile) !Object {
    var arr = std.ArrayList(ObjectFieldInfo).init(allocator);
    try genStaticFieldInfo(allocator, &arr, class_file);
    return init(allocator, class_file, arr.toOwnedSlice());
}

pub fn init(allocator: *std.mem.Allocator, class_file: *ClassFile, field_info: []ObjectFieldInfo) !Object {
    var fields_size: usize = 0;

    for (field_info) |field| {
        fields_size += field.kind.sizeOf();
    }

    var field_data_pool = try allocator.alloc(u8, fields_size);
    for (field_data_pool) |*v| v.* = 0;

    return Object{
        .allocator = allocator,
        .class_file = class_file,
        .field_info = field_info,
        .field_data_pool = field_data_pool,
    };
}

/// Caller owns memory; `self.allocator.free(class_name)`.
pub fn getClassName(self: Object) ![]const u8 {
    var class_name_slashes = self.class_file.this_class.getName(self.class_file.constant_pool);
    return try utils.classToDots(self.allocator, class_name_slashes);
}

pub fn deinit(self: *Object) void {
    self.allocator.free(self.field_data_pool);
}

fn getFieldIndex(self: *Object, name: []const u8) !usize {
    for (self.field_info) |fi, i| {
        if (std.hash.Wyhash.hash(i, name) == fi.hash) return i;
    }

    return error.FieldNotFound;
}

pub fn setField(self: *Object, name: []const u8, value: primitives.PrimitiveValue) !void {
    var ind = try self.getFieldIndex(name);
    var offset: usize = 0;

    var i: usize = 0;
    while (i < ind) : (i += 1) {
        offset += self.field_info[i].kind.sizeOf();
    }

    var x = self.field_info[i].kind;
    inline for (std.meta.fields(primitives.PrimitiveValueKind)) |f| {
        if (@enumToInt(primitives.PrimitiveValueKind.@"void") == f.value) continue;
        if (@enumToInt(x) == f.value) {
            std.mem.copy(u8, self.field_data_pool[offset .. offset + x.sizeOf()], &std.mem.toBytes(@field(value, f.name)));
            return;
        }
    }

    unreachable;
}

pub fn getField(self: *Object, name: []const u8) ?primitives.PrimitiveValue {
    var ind = self.getFieldIndex(name) catch return null;
    var offset: usize = 0;

    var i: usize = 0;
    while (i < ind) : (i += 1) {
        offset += self.field_info[i].kind.sizeOf();
    }

    var x = self.field_info[i].kind;
    inline for (std.meta.fields(primitives.PrimitiveValueKind)) |f| {
        if (@enumToInt(primitives.PrimitiveValueKind.@"void") == f.value) continue;
        if (@enumToInt(x) == f.value) {
            const k = @intToEnum(primitives.PrimitiveValueKind, f.value);
            return @unionInit(primitives.PrimitiveValue, f.name, std.mem.bytesToValue(k.getType(), self.field_data_pool[offset .. offset + x.sizeOf()][0..comptime k.sizeOf()]));
        }
    }

    unreachable;
}
