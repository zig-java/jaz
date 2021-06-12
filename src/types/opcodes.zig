pub const Opcode = enum(u8) {
    nop = 0x00,
    aconst_null = 0x01,
    iconst_m1 = 0x02,
    iconst_0 = 0x03,
    iconst_1 = 0x04,
    iconst_2 = 0x05,
    iconst_3 = 0x06,
    iconst_4 = 0x07,
    iconst_5 = 0x08,
    lconst_0 = 0x09,
    lconst_1 = 0x0a,
    fconst_0 = 0x0b,
    fconst_1 = 0x0c,
    fconst_2 = 0x0d,
    dconst_0 = 0x0e,
    dconst_1 = 0x0f,
    bipush = 0x10,
    sipush = 0x11,
    ldc = 0x12,
    ldc_w = 0x13,
    ldc2_w = 0x14,
    iload = 0x15,
    lload = 0x16,
    fload = 0x17,
    dload = 0x18,
    aload = 0x19,
    iload_0 = 0x1a,
    iload_1 = 0x1b,
    iload_2 = 0x1c,
    iload_3 = 0x1d,
    lload_0 = 0x1e,
    lload_1 = 0x1f,
    lload_2 = 0x20,
    lload_3 = 0x21,
    fload_0 = 0x22,
    fload_1 = 0x23,
    fload_2 = 0x24,
    fload_3 = 0x25,
    dload_0 = 0x26,
    dload_1 = 0x27,
    dload_2 = 0x28,
    dload_3 = 0x29,
    aload_0 = 0x2a,
    aload_1 = 0x2b,
    aload_2 = 0x2c,
    aload_3 = 0x2d,
    iaload = 0x2e,
    laload = 0x2f,
    faload = 0x30,
    daload = 0x31,
    aaload = 0x32,
    baload = 0x33,
    caload = 0x34,
    saload = 0x35,
    istore = 0x36,
    lstore = 0x37,
    fstore = 0x38,
    dstore = 0x39,
    astore = 0x3a,
    istore_0 = 0x3b,
    istore_1 = 0x3c,
    istore_2 = 0x3d,
    istore_3 = 0x3e,
    lstore_0 = 0x3f,
    lstore_1 = 0x40,
    lstore_2 = 0x41,
    lstore_3 = 0x42,
    fstore_0 = 0x43,
    fstore_1 = 0x44,
    fstore_2 = 0x45,
    fstore_3 = 0x46,
    dstore_0 = 0x47,
    dstore_1 = 0x48,
    dstore_2 = 0x49,
    dstore_3 = 0x4a,
    astore_0 = 0x4b,
    astore_1 = 0x4c,
    astore_2 = 0x4d,
    astore_3 = 0x4e,
    iastore = 0x4f,
    lastore = 0x50,
    fastore = 0x51,
    dastore = 0x52,
    aastore = 0x53,
    bastore = 0x54,
    castore = 0x55,
    sastore = 0x56,
    pop = 0x57,
    pop2 = 0x58,
    dup = 0x59,
    dup_x1 = 0x5a,
    dup_x2 = 0x5b,
    dup2 = 0x5c,
    dup2_x1 = 0x5d,
    dup2_x2 = 0x5e,
    swap = 0x5f,
    iadd = 0x60,
    ladd = 0x61,
    fadd = 0x62,
    dadd = 0x63,
    isub = 0x64,
    lsub = 0x65,
    fsub = 0x66,
    dsub = 0x67,
    imul = 0x68,
    lmul = 0x69,
    fmul = 0x6a,
    dmul = 0x6b,
    idiv = 0x6c,
    ldiv = 0x6d,
    fdiv = 0x6e,
    ddiv = 0x6f,
    irem = 0x70,
    lrem = 0x71,
    frem = 0x72,
    drem = 0x73,
    ineg = 0x74,
    lneg = 0x75,
    fneg = 0x76,
    dneg = 0x77,
    ishl = 0x78,
    lshl = 0x79,
    ishr = 0x7a,
    lshr = 0x7b,
    iushr = 0x7c,
    lushr = 0x7d,
    iand = 0x7e,
    land = 0x7f,
    ior = 0x80,
    lor = 0x81,
    ixor = 0x82,
    lxor = 0x83,
    iinc = 0x84,
    i2l = 0x85,
    i2f = 0x86,
    i2d = 0x87,
    l2i = 0x88,
    l2f = 0x89,
    l2d = 0x8a,
    f2i = 0x8b,
    f2l = 0x8c,
    f2d = 0x8d,
    d2i = 0x8e,
    d2l = 0x8f,
    d2f = 0x90,
    i2b = 0x91,
    i2c = 0x92,
    i2s = 0x93,
    lcmp = 0x94,
    fcmpl = 0x95,
    fcmpg = 0x96,
    dcmpl = 0x97,
    dcmpg = 0x98,
    ifeq = 0x99,
    ifne = 0x9a,
    iflt = 0x9b,
    ifge = 0x9c,
    ifgt = 0x9d,
    ifle = 0x9e,
    if_icmpeq = 0x9f,
    if_icmpne = 0xa0,
    if_icmplt = 0xa1,
    if_icmpge = 0xa2,
    if_icmpgt = 0xa3,
    if_icmple = 0xa4,
    if_acmpeq = 0xa5,
    if_acmpne = 0xa6,
    goto = 0xa7,
    jsr = 0xa8,
    ret = 0xa9,
    tableswitch = 0xaa,
    lookupswitch = 0xab,
    ireturn = 0xac,
    lreturn = 0xad,
    freturn = 0xae,
    dreturn = 0xaf,
    areturn = 0xb0,
    @"return" = 0xb1,
    getstatic = 0xb2,
    putstatic = 0xb3,
    getfield = 0xb4,
    putfield = 0xb5,
    invokevirtual = 0xb6,
    invokespecial = 0xb7,
    invokestatic = 0xb8,
    invokeinterface = 0xb9,
    invokedynamic = 0xba,
    new = 0xbb,
    newarray = 0xbc,
    anewarray = 0xbd,
    arraylength = 0xbe,
    athrow = 0xbf,
    checkcast = 0xc0,
    instanceof = 0xc1,
    monitorenter = 0xc2,
    monitorexit = 0xc3,
    wide = 0xc4,
    multianewarray = 0xc5,
    ifnull = 0xc6,
    ifnonnull = 0xc7,
    goto_w = 0xc8,
    jsr_w = 0xc9,
    breakpoint = 0xca,
    impdep1 = 0xfe,
    impdep2 = 0xff,

    pub fn resolve(op: u8) Opcode {
        return @intToEnum(Opcode, op);
    }
};

// TODO: Rename these; why did I even name these types like this????
pub const LocalIndexOperation = u8;
pub const ConstantPoolRefOperation = u16;
pub const BranchToOffsetOperation = i16;
pub const BranchToOffsetWideOperation = i32;

pub const bipush_params = i8;
pub const sipush_params = i16;

pub const iinc_params = packed struct { index: LocalIndexOperation, @"const": i8 };

//

pub const invokedynamic_params = packed struct { indexbyte1: u8, indexbyte2: u8, pad: u16 };

pub const invokeinterface_params = packed struct { indexbyte1: u8, indexbyte2: u8, count: u8, pad: u8 };

/// TODO
pub const LookupPair = struct {
    match: i32,
    offset: i32,
};
pub const lookupswitch_params = struct {
    skipped_bytes: usize,
    default_offset: i32,
    pairs: []LookupPair,

    pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !lookupswitch_params {
        var skipped_bytes = std.mem.alignForward(reader.context.pos, 4) - reader.context.pos;
        try reader.skipBytes(skipped_bytes, .{});

        const default_offset = try reader.readIntBig(i32);
        const npairs = try reader.readIntBig(i32);

        var pairs = try allocator.alloc(LookupPair, @intCast(usize, npairs));
        for (pairs) |*pair|
            pair.* = LookupPair{
                .match = try reader.readIntBig(i32),
                .offset = try reader.readIntBig(i32),
            };

        return lookupswitch_params{
            .skipped_bytes = skipped_bytes,
            .default_offset = default_offset,
            .pairs = pairs,
        };
    }
};

pub const tableswitch_params = struct {
    skipped_bytes: usize,
    default_offset: i32,
    low: i32,
    high: i32,
    jumps: []i32,

    pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !tableswitch_params {
        var skipped_bytes = std.mem.alignForward(reader.context.pos, 4) - reader.context.pos;
        try reader.skipBytes(skipped_bytes, .{});

        const default_offset = try reader.readIntBig(i32);
        const low = try reader.readIntBig(i32);
        const high = try reader.readIntBig(i32);

        var jumps = try allocator.alloc(i32, @intCast(usize, high - low + 1));
        for (jumps) |*jump|
            jump.* = try reader.readIntBig(i32);

        return tableswitch_params{
            .skipped_bytes = skipped_bytes,
            .default_offset = default_offset,
            .low = low,
            .high = high,
            .jumps = jumps,
        };
    }
};

pub const multianewarray_params = packed struct { index: ConstantPoolRefOperation, dimensions: u8 };

pub const newarray_params = packed enum(u8) {
    boolean = 4,
    char = 5,
    float = 6,
    double = 7,
    byte = 8,
    short = 9,
    int = 10,
    long = 11,
};

pub const Operation = union(Opcode) {
    const Self = @This();

    aload: LocalIndexOperation,
    anewarray: ConstantPoolRefOperation,
    astore: LocalIndexOperation,
    bipush: bipush_params,
    checkcast: ConstantPoolRefOperation,
    dload: LocalIndexOperation,
    dstore: LocalIndexOperation,
    fload: LocalIndexOperation,
    fstore: LocalIndexOperation,
    getfield: ConstantPoolRefOperation,
    getstatic: ConstantPoolRefOperation,

    goto: BranchToOffsetOperation,
    if_acmpeq: BranchToOffsetOperation,
    if_acmpne: BranchToOffsetOperation,
    if_icmpeq: BranchToOffsetOperation,
    if_icmpge: BranchToOffsetOperation,
    if_icmpgt: BranchToOffsetOperation,
    if_icmple: BranchToOffsetOperation,
    if_icmplt: BranchToOffsetOperation,
    if_icmpne: BranchToOffsetOperation,
    ifeq: BranchToOffsetOperation,
    ifge: BranchToOffsetOperation,
    ifgt: BranchToOffsetOperation,
    ifle: BranchToOffsetOperation,
    iflt: BranchToOffsetOperation,
    ifne: BranchToOffsetOperation,
    ifnonnull: BranchToOffsetOperation,
    ifnull: BranchToOffsetOperation,
    jsr: BranchToOffsetOperation,

    goto_w: BranchToOffsetWideOperation,
    jsr_w: BranchToOffsetWideOperation,

    iinc: iinc_params,
    iload: LocalIndexOperation,
    instanceof: ConstantPoolRefOperation,
    invokedynamic: invokedynamic_params,
    invokeinterface: invokeinterface_params,
    invokespecial: ConstantPoolRefOperation,
    invokestatic: ConstantPoolRefOperation,
    invokevirtual: ConstantPoolRefOperation,
    istore: LocalIndexOperation,
    ldc: u8, // NOTE: This is not a local variable! It's probably for compat
    ldc_w: ConstantPoolRefOperation,
    ldc2_w: ConstantPoolRefOperation,
    lookupswitch: lookupswitch_params,
    tableswitch: tableswitch_params,
    new: ConstantPoolRefOperation,
    multianewarray: multianewarray_params,
    lload: LocalIndexOperation,
    lstore: LocalIndexOperation,
    sipush: sipush_params,
    putstatic: ConstantPoolRefOperation,
    putfield: ConstantPoolRefOperation,
    newarray: newarray_params,

    nop,
    aconst_null,
    iconst_m1,
    iconst_0,
    iconst_1,
    iconst_2,
    iconst_3,
    iconst_4,
    iconst_5,
    lconst_0,
    lconst_1,
    fconst_0,
    fconst_1,
    fconst_2,
    dconst_0,
    dconst_1,
    iload_0,
    iload_1,
    iload_2,
    iload_3,
    lload_0,
    lload_1,
    lload_2,
    lload_3,
    fload_0,
    fload_1,
    fload_2,
    fload_3,
    dload_0,
    dload_1,
    dload_2,
    dload_3,
    aload_0,
    aload_1,
    aload_2,
    aload_3,
    iaload,
    laload,
    faload,
    daload,
    aaload,
    baload,
    caload,
    saload,
    istore_0,
    istore_1,
    istore_2,
    istore_3,
    lstore_0,
    lstore_1,
    lstore_2,
    lstore_3,
    fstore_0,
    fstore_1,
    fstore_2,
    fstore_3,
    dstore_0,
    dstore_1,
    dstore_2,
    dstore_3,
    astore_0,
    astore_1,
    astore_2,
    astore_3,
    iastore,
    lastore,
    fastore,
    dastore,
    aastore,
    bastore,
    castore,
    sastore,
    pop,
    pop2,
    dup,
    dup_x1,
    dup_x2,
    dup2,
    dup2_x1,
    dup2_x2,
    swap,
    iadd,
    ladd,
    fadd,
    dadd,
    isub,
    lsub,
    fsub,
    dsub,
    imul,
    lmul,
    fmul,
    dmul,
    idiv,
    ldiv,
    fdiv,
    ddiv,
    irem,
    lrem,
    frem,
    drem,
    ineg,
    lneg,
    fneg,
    dneg,
    ishl,
    lshl,
    ishr,
    lshr,
    iushr,
    lushr,
    iand,
    land,
    ior,
    lor,
    ixor,
    lxor,
    i2l,
    i2f,
    i2d,
    l2i,
    l2f,
    l2d,
    f2i,
    f2l,
    f2d,
    d2i,
    d2l,
    d2f,
    i2b,
    i2c,
    i2s,
    lcmp,
    fcmpl,
    fcmpg,
    dcmpl,
    dcmpg,
    ret,
    ireturn,
    lreturn,
    freturn,
    dreturn,
    areturn,
    @"return",
    arraylength,
    athrow,
    monitorenter,
    monitorexit,
    wide,
    breakpoint,
    impdep1,
    impdep2,

    pub fn sizeOf(self: Self) usize {
        inline for (std.meta.fields(Self)) |op| {
            if (@enumToInt(std.meta.stringToEnum(Opcode, op.name).?) == @enumToInt(self)) {
                return 1 + if (op.field_type == void) 0 else @sizeOf(op.field_type);
            }
        }

        unreachable;
    }

    pub fn parse(allocator: *std.mem.Allocator, reader: anytype) !Self {
        var opcode = try reader.readIntBig(u8);

        inline for (std.meta.fields(Self)) |op| {
            if (@enumToInt(std.meta.stringToEnum(Opcode, op.name).?) == opcode) {
                return @unionInit(Self, op.name, if (op.field_type == void) {} else if (@typeInfo(op.field_type) == .Struct) z: {
                    break :z if (@hasDecl(op.field_type, "parse")) try @field(op.field_type, "parse")(allocator, reader) else try reader.readStruct(op.field_type);
                } else if (@typeInfo(op.field_type) == .Enum) try reader.readEnum(op.field_type, .Big) else if (@typeInfo(op.field_type) == .Int) try reader.readIntBig(op.field_type) else unreachable);
            }
        }

        unreachable;
    }
};

const std = @import("std");

/// Get the index specified by an operation, if possible
pub fn getIndex(inst: anytype) u16 {
    if (!@hasField(@TypeOf(inst), "indexbyte1")) @compileError("This instruction does not have an index!");
    return @intCast(u16, @field(inst, "indexbyte1")) << @intCast(u16, 8) | @intCast(u16, @field(inst, "indexbyte2"));
}
