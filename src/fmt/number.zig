const std = @import("std");

var allocator = @import("../util.zig").allocator;

// COMMON

const SEGMENT_BITS: u8 = 0x7F;
const CONTINUE_BIT: u8 = 0x80;

const native_endian = @import("builtin").cpu.arch.endian();

// READING

pub const VarNumError = error{
    number_too_big,
    buffer_too_small,
};

// Read a variable-length integer.
pub fn readVarInt(bytes: []const u8) !struct { i32, usize } {
    var length: u5 = 0;
    var result: i32 = 0;
    var current: i32 = 0;

    while (true) : (length += 1) {
        if (length > 5) return VarNumError.number_too_big;

        current = @intCast(bytes[length]);
        result |= (current & SEGMENT_BITS) << (7 * length);

        if ((current & CONTINUE_BIT) == 0) break;
    }

    return .{ result, length + 1 };
}

// Read a variable-length long.
pub fn readVarLong(bytes: []const u8) !struct { i64, usize } {
    var length: u6 = 0;
    var result: i64 = 0;
    var current: i64 = 0;

    while (true) : (length += 1) {
        if (length > 10) return VarNumError.number_too_big;

        current = @intCast(bytes[length]);
        result |= (current & SEGMENT_BITS) << (7 * length);

        if ((current & CONTINUE_BIT) == 0) break;
    }

    return .{ result, length + 1 };
}

// Read a fixed-point number.
pub inline fn readFixedPoint(bytes: []const u8) f32 {
    return @as(f32, @floatFromInt(readBig(i32, bytes))) * 32.0;
}

// Read any number in big-endian format.
pub inline fn readBig(comptime T: type, bytes: []const u8) T {
    return readInner(T, bytes, .big);
}

// Read any number in little-endian format.
pub inline fn readLittle(comptime T: type, bytes: []const u8) T {
    return readInner(T, bytes, .little);
}

// Inner function used for reading.
fn readInner(comptime T: type, bytes: []const u8, endianness: std.builtin.Endian) T {
    const type_info = @typeInfo(T);
    comptime if (type_info != .Int and type_info != .Float) @compileError("bad input type");

    const size = @sizeOf(T);
    var output = [1]u8{0} ** size;

    if (native_endian != endianness) {
        comptime var i: usize = size;
        inline while (i > 0) : (i -= 1) output[size - i] = bytes[i - 1];
    } else {
        @memcpy(&output, bytes);
    }

    return @bitCast(output);
}

// WRITING

// Write a variable-length integer, allocating a buffer.
pub inline fn writeVarIntAlloc(value: i32) ![]const u8 {
    var output = try allocator.alloc(u8, 5);
    const len = writeVarIntBuf(value, @ptrCast(output[0..]));
    _ = allocator.resize(output, len);
    return output[0..len];
}

// Write a variable-length integer using a pre-existing buffer.
pub fn writeVarIntBuf(value: i32, output: *[5]u8) usize {
    var tmp = value;
    var i: usize = 0;

    while (i < 5) : (i += 1) {
        if ((tmp & ~SEGMENT_BITS) == 0) {
            output[i] = @intCast(tmp);
            i += 1;
            break;
        }

        output[i] = @intCast((tmp & SEGMENT_BITS) | CONTINUE_BIT);

        tmp = @bitCast(@as(u32, @bitCast(tmp)) >> 7); // unsigned right shift
    }

    return i;
}

// Write a variable-length long, allocating a buffer.
pub inline fn writeVarLongAlloc(value: i64) ![]const u8 {
    var output = try allocator.alloc(u8, 10);
    const len = writeVarLongBuf(value, @ptrCast(output[0..]));
    _ = allocator.resize(output, len);
    return output[0..len];
}

// Write a variable-length long using a pre-existing buffer.
pub fn writeVarLongBuf(value: i64, output: *[10]u8) usize {
    var tmp = value;
    var i: usize = 0;

    while (i < 10) : (i += 1) {
        if ((tmp & ~SEGMENT_BITS) == 0) {
            output[i] = @intCast(tmp);
            i += 1;
            break;
        }

        output[i] = @intCast((tmp & SEGMENT_BITS) | CONTINUE_BIT);

        tmp = @bitCast(@as(u64, @bitCast(tmp)) >> 7); // unsigned right shift
    }

    return i;
}

// Write a fixed-point number. Writes to a buffer.
pub inline fn writeFixedPointBuf(value: f32, buf: *[4]u8) []const u8 {
    return writeBigBuf(i32, @intFromFloat(value / 32.0), buf);
}

// Write a fixed-point number. Allocates a buffer.
pub inline fn writeFixedPointAlloc(value: f32) ![]const u8 {
    return writeBigAlloc(i32, @as(i32, @intFromFloat(value / 32.0)));
}

// Write any number in big-endian format. Writes to a buffer.
pub inline fn writeBigBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8) void {
    return writeInnerBuf(T, value, buf, .big);
}

// Write any number in little-endian format. Writes to a buffer.
pub inline fn writeLittleBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8) void {
    return writeInnerBuf(T, value, buf, .little);
}

// Write any number in big-endian format. Allocates a buffer.
pub inline fn writeBigAlloc(comptime T: type, value: T) ![]const u8 {
    return writeInnerAlloc(T, value, .big);
}

// Write any number in little-endian format. Allocates a buffer.
pub inline fn writeLittleAlloc(comptime T: type, value: T) ![]const u8 {
    return writeInnerAlloc(T, value, .little);
}

// Inner function used for writing. Writes to a buffer.
// std.mem.writeIntBig/Little is not used because it doesn't support floats.
fn writeInnerBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8, endianness: std.builtin.Endian) void {
    const type_info = @typeInfo(T);
    comptime if (type_info != .Int and type_info != .Float) @compileError("bad input type");

    const size = @sizeOf(T);
    const bytes: [size]u8 = @bitCast(value);

    if (native_endian != endianness) {
        comptime var i: usize = size;
        inline while (i > 0) : (i -= 1) buf.*[size - i] = bytes[i - 1];
    } else {
        @memcpy(buf, &bytes);
    }
}

// Inner function used for writing. Allocates a buffer.
// std.mem.writeIntBig/Little is not used because it doesn't support floats.
fn writeInnerAlloc(comptime T: type, value: T, endianness: std.builtin.Endian) ![]const u8 {
    const size = @sizeOf(T);
    const buf = try allocator.alloc(u8, size);
    writeInnerBuf(T, value, @as(*[size]u8, @ptrCast(buf)), endianness);
    return buf;
}

// TESTS

test {
    allocator = std.testing.allocator;
}

test "read/write VarInt" {
    const written = try writeVarIntAlloc(5);
    defer allocator.free(written);
    const read_back = (try readVarInt(written))[0];

    try std.testing.expect(read_back == 5);
}

test "read/write VarLong" {
    const written = try writeVarLongAlloc(5);
    defer allocator.free(written);
    const read_back = (try readVarLong(written))[0];

    try std.testing.expect(read_back == 5);
}

test "read/write fixed-point" {
    const written = try writeFixedPointAlloc(32.0);
    defer allocator.free(written);
    const read_back = readFixedPoint(written);

    try std.testing.expect(read_back == 32.0);
}

test "read/write big-endian" {
    const written = try writeBigAlloc(isize, 5);
    defer allocator.free(written);
    const read_back = readBig(isize, written);

    try std.testing.expect(read_back == 5);
}

test "read/write little-endian" {
    const written = try writeLittleAlloc(usize, 5);
    defer allocator.free(written);
    const read_back = readLittle(usize, written);

    try std.testing.expect(read_back == 5);
}
