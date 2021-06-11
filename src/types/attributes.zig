const std = @import("std");
const ClassFile = @import("ClassFile.zig");

const AttributeMap = std.ComptimeStringMap([]const u8, .{.{ "Code", "code" }});

// TODO: Implement all attribute types
pub const AttributeData = union(enum) { code: CodeAttribute, unknown: void };

pub const AttributeInfo = struct {
    const Self = @This();

    attribute_name_index: u16,
    /// Don't access this directly! Use readData!
    info: []u8,

    pub fn getName(self: Self, class_file: ClassFile) []const u8 {
        return class_file.getConstantPoolEntry(self.attribute_name_index).utf8.bytes;
    }

    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var attribute_name_index = try reader.readIntBig(u16);
        var attribute_length = try reader.readIntBig(u32);

        var info = try allocator.alloc(u8, attribute_length);
        _ = try reader.readAll(info);

        return Self{ .attribute_name_index = attribute_name_index, .info = info };
    }

    pub fn readData(self: Self, allocator: *std.mem.Allocator, class_file: ClassFile) !AttributeData {
        var fbs = std.io.fixedBufferStream(self.info);
        var name = self.getName(class_file);

        inline for (std.meta.fields(AttributeData)) |d| {
            if (AttributeMap.get(name) != null)
                if (std.mem.eql(u8, AttributeMap.get(name).?, d.name)) {
                    return @unionInit(AttributeData, d.name, if (d.field_type == void) {} else try @field(d.field_type, "readFrom")(allocator, fbs.reader()));
                };
        }

        return .unknown;
    }
};

pub const ExceptionTableEntry = packed struct {
    const Self = @This();

    /// Where the exception handler becomes active (inclusive)
    start_pc: u16,
    /// Where it becomes inactive (exclusive)
    end_pc: u16,
    /// Start of handler
    handler_pc: u16,
    /// Index into constant pool
    catch_type: u16,

    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        return try reader.readStruct(Self);
    }
};

pub const CodeAttribute = struct {
    const Self = @This();

    max_stack: u16,
    max_locals: u16,

    code: []u8,
    exception_table: []ExceptionTableEntry,

    attributes: []AttributeInfo,

    pub fn readFrom(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var max_stack = try reader.readIntBig(u16);
        var max_locals = try reader.readIntBig(u16);

        var code_length = try reader.readIntBig(u32);
        var code = try allocator.alloc(u8, code_length);
        _ = try reader.readAll(code);

        var exception_table_length = try reader.readIntBig(u16);
        var exception_table = try allocator.alloc(ExceptionTableEntry, exception_table_length);
        for (exception_table) |*et| et.* = try ExceptionTableEntry.readFrom(allocator, reader);

        var attributes_count = try reader.readIntBig(u16);
        var attributes = try allocator.alloc(AttributeInfo, attributes_count);
        for (attributes) |*at| at.* = try AttributeInfo.readFrom(allocator, reader);

        return Self{
            .max_stack = max_stack,
            .max_locals = max_locals,

            .code = code,
            .exception_table = exception_table,

            .attributes = attributes,
        };
    }
};
