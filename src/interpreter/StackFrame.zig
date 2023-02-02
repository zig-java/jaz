const std = @import("std");

const primitives = @import("./primitives.zig");
const Stack = @import("Stack.zig");

const cf = @import("cf");
const ClassFile = cf.ClassFile;

const Self = @This();

local_variables: std.ArrayList(primitives.PrimitiveValue),
operand_stack: Stack,
class_file: *const ClassFile,

pub fn init(allocator: std.mem.Allocator, class_file: *const ClassFile) Self {
    return .{
        .local_variables = std.ArrayList(primitives.PrimitiveValue).init(allocator),
        .operand_stack = Stack.init(allocator),
        .class_file = class_file,
    };
}

pub fn setLocalVariable(self: *Self, index: usize, value: primitives.PrimitiveValue) !void {
    try self.local_variables.ensureTotalCapacity(index + 1);
    self.local_variables.expandToCapacity();
    self.local_variables.items[index] = value;
}

pub fn deinit(self: *Self) void {
    self.local_variables.deinit();
    self.operand_stack.deinit();
}
