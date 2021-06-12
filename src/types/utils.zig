pub fn isPresent(comptime T: type, u: T, c: T) bool {
    return u & c == c;
}
