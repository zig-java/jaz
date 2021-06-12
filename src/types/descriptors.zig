const std = @import("std");

pub const MethodDescriptor = struct {
    const Self = @This();

    parameters: []*Descriptor,
    return_type: *Descriptor,

    pub fn stringify(self: Self, writer: anytype) anyerror!void {
        try writer.writeByte('(');
        for (self.parameters) |param| try param.stringify(writer);
        try writer.writeByte(')');
        try self.return_type.stringify(writer);
    }

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
        for (self.parameters) |*param| param.*.deinit(allocator);
        allocator.free(self.parameters);
        self.return_type.deinit(allocator);
    }
};

pub const Descriptor = union(enum) {
    const Self = @This();

    byte,
    char,

    int,
    long,
    short,

    float,
    double,

    boolean: void,

    object: []const u8,
    array: *Descriptor,
    method: MethodDescriptor,

    /// Only valid for method `return_type`s
    @"void": void,

    pub fn stringify(self: Self, writer: anytype) anyerror!void {
        switch (self) {
            .byte => try writer.writeByte('B'),
            .char => try writer.writeByte('C'),

            .int => try writer.writeByte('I'),
            .long => try writer.writeByte('J'),
            .short => try writer.writeByte('S'),

            .float => try writer.writeByte('F'),
            .double => try writer.writeByte('D'),

            .boolean => try writer.writeByte('Z'),
            .void => try writer.writeByte('V'),

            .object => |o| try writer.print("L{s};", .{o}),
            .array => |a| {
                try writer.writeByte('[');
                try a.stringify(writer);
            },
            .method => |m| try m.stringify(writer),
        }
    }

    pub fn toStringArrayList(self: Self, buf: *std.ArrayList(u8)) !void {
        try buf.ensureCapacity(0);
        try self.stringify(buf.writer());
    }

    pub fn humanStringify(self: Self, writer: anytype) anyerror!void {
        try switch (self) {
            .byte => _ = try writer.writeAll("byte"),
            .char => _ = try writer.writeAll("char"),

            .int => _ = try writer.writeAll("int"),
            .long => _ = try writer.writeAll("long"),
            .short => _ = try writer.writeAll("short"),

            .float => _ = try writer.writeAll("float"),
            .double => _ = try writer.writeAll("double"),

            .boolean => _ = try writer.writeAll("boolean"),
            .void => _ = try writer.writeAll("void"),

            .object => |o| {
                var i: usize = 0;
                var tc = std.mem.count(u8, o, "/");
                var t = std.mem.tokenize(o, "/");
                while (t.next()) |z| : (i += 1) {
                    _ = try writer.writeAll(z);
                    if (i != tc) try writer.writeByte('.');
                }
            },
            .array => |a| {
                try a.humanStringify(writer);
                _ = try writer.writeAll("[]");
            },
            .method => error.NotImplemented,
        };
    }

    pub fn toHumanStringArrayList(self: Self, buf: *std.ArrayList(u8)) !void {
        try buf.ensureCapacity(0);
        try self.humanStringify(buf.writer());
    }

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
        switch (self.*) {
            .object => |*o| allocator.free(o.*),
            .array => |*a| a.*.deinit(allocator),
            .method => |*m| m.*.deinit(allocator),

            else => {},
        }
        allocator.destroy(self);
    }
};

fn c(allocator: *std.mem.Allocator, d: Descriptor) !*Descriptor {
    var x = try allocator.create(Descriptor);
    x.* = d;
    return x;
}

fn parse_(allocator: *std.mem.Allocator, reader: anytype) anyerror!?*Descriptor {
    var kind = try reader.readByte();
    switch (kind) {
        'B' => return try c(allocator, .byte),
        'C' => return try c(allocator, .char),

        'I' => return try c(allocator, .int),
        'J' => return try c(allocator, .long),
        'S' => return try c(allocator, .short),

        'F' => return try c(allocator, .float),
        'D' => return try c(allocator, .double),

        'Z' => return try c(allocator, .boolean),

        'V' => return try c(allocator, .void),

        'L' => {
            var x = try allocator.create(Descriptor);
            x.* = .{ .object = try reader.readUntilDelimiterAlloc(allocator, ';', 256) };
            return x;
        },
        '[' => {
            var x = try allocator.create(Descriptor);
            x.* = .{ .array = try parse(allocator, reader) };
            return x;
        },
        '(' => {
            var params = std.ArrayList(*Descriptor).init(allocator);
            defer params.deinit();

            while (try parse_(allocator, reader)) |k| {
                try params.append(k);
            }

            var returnd = (try parse_(allocator, reader)).?;

            var x = try allocator.create(Descriptor);
            x.* = .{ .method = .{ .parameters = params.toOwnedSlice(), .return_type = returnd } };
            return x;
        },
        ')' => return null,

        else => unreachable,
    }
}

pub fn parse(allocator: *std.mem.Allocator, reader: anytype) anyerror!*Descriptor {
    return (try parse_(allocator, reader)).?;
}

pub fn parseString(allocator: *std.mem.Allocator, string: []const u8) !*Descriptor {
    var fbs = std.io.fixedBufferStream(string);
    return parse(allocator, fbs.reader());
}

test "Descriptors: Write/parse 3D array of objects" {
    var test_string = "[[[Ljava/lang/Object;";

    var object = Descriptor{ .object = "java/lang/Object" };
    var array1 = Descriptor{ .array = &object };
    var array2 = Descriptor{ .array = &array1 };
    var desc = Descriptor{ .array = &array2 };

    var out_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer out_buf.deinit();

    try desc.stringify(out_buf.writer());
    try std.testing.expectEqualStrings(test_string, out_buf.items);

    var fbs = std.io.fixedBufferStream(test_string);
    var parsed_desc = try parse(std.testing.allocator, fbs.reader());
    defer parsed_desc.deinit(std.testing.allocator);

    out_buf.shrinkRetainingCapacity(0);
    try parsed_desc.stringify(out_buf.writer());
    try std.testing.expectEqualStrings(test_string, out_buf.items);
}

test "Descriptors: Write/parse method that returns an object and accepts an integer, double, and Thread" {
    var test_string = "(IDLjava/lang/Thread;)Ljava/lang/Object;";

    var int = Descriptor{ .int = {} };
    var double = Descriptor{ .double = {} };
    var thread = Descriptor{ .object = "java/lang/Thread" };

    var object = Descriptor{ .object = "java/lang/Object" };

    var desc = Descriptor{ .method = .{ .parameters = &.{ &int, &double, &thread }, .return_type = &object } };

    var out_buf = std.ArrayList(u8).init(std.testing.allocator);
    defer out_buf.deinit();

    try desc.stringify(out_buf.writer());
    try std.testing.expectEqualStrings(test_string, out_buf.items);

    var fbs = std.io.fixedBufferStream(test_string);
    var parsed_desc = try parse(std.testing.allocator, fbs.reader());
    defer parsed_desc.deinit(std.testing.allocator);

    out_buf.shrinkRetainingCapacity(0);
    try parsed_desc.stringify(out_buf.writer());
    try std.testing.expectEqualStrings(test_string, out_buf.items);
}
