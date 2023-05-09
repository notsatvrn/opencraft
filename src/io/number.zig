const std = @import("std");

const allocator = @import("../global.zig").allocator;

// COMMON

const SEGMENT_BITS: u8 = 0x7F;
const CONTINUE_BIT: u8 = 0x80;

const native_endian = @import("builtin").cpu.arch.endian();

// READING

pub const VarNumError = error{
    too_big,
};

// Read a variable-length integer.
pub fn readVarInt(bytes: []const u8) !struct { i32, usize } {
    var length: u5 = 0;
    var result: i32 = 0;
    var current: i32 = 0;

    while (true) : (length += 1) {
        if (length > 5) return VarNumError.too_big;

        current = @intCast(i32, bytes[length]);
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
        if (length > 10) return VarNumError.too_big;

        current = @intCast(i64, bytes[length]);
        result |= (current & SEGMENT_BITS) << (7 * length);

        if ((current & CONTINUE_BIT) == 0) break;
    }

    return .{ result, length + 1 };
}

// Read a fixed-point number.
pub fn readFixedPoint(bytes: []const u8) f32 {
    return @intToFloat(f32, readBig(i32, bytes)) * 32.0;
}

// Read any number in big-endian format.
pub fn readBig(comptime T: type, bytes: []const u8) T {
    return readInner(T, bytes, .Big);
}

// Read any number in little-endian format.
pub fn readLittle(comptime T: type, bytes: []const u8) T {
    return readInner(T, bytes, .Little);
}

// Inner function used for reading.
fn readInner(comptime T: type, bytes: []const u8, endianness: std.builtin.Endian) T {
    const type_info = @typeInfo(T);

    if (type_info == .Int or type_info == .Float) {
        const size = @sizeOf(T);
        var output = [1]u8{0} ** size;

        if (native_endian != endianness) {
            var i: usize = size;
            while (i > 0) : (i -= 1) output[size - i] = bytes[i - 1];
        } else {
            output = @constCast(bytes[0..size]).*;
        }

        return @bitCast(T, output);
    } else {
        @compileError("bad input type");
    }
}

// WRITING

// Write a variable-length integer.
pub fn writeVarInt(value: i32) ![]const u8 {
    var output = try std.ArrayList(u8).initCapacity(allocator, 5);
    var tmp = value;

    while (true) {
        if ((tmp & ~SEGMENT_BITS) == 0) {
            output.appendAssumeCapacity(@truncate(u8, @intCast(u32, tmp)));
            break;
        }

        output.appendAssumeCapacity(@truncate(u8, @intCast(u32, (tmp & SEGMENT_BITS) | CONTINUE_BIT)));

        tmp = @intCast(i32, @bitCast(u32, tmp) >> 7); // unsigned right shift
    }

    return output.toOwnedSlice();
}

// Write a variable-length long.
pub fn writeVarLong(value: i64) ![]const u8 {
    var output = try std.ArrayList(u8).initCapacity(allocator, 10);
    var tmp = value;

    while (true) {
        if ((tmp & ~SEGMENT_BITS) == 0) {
            output.appendAssumeCapacity(@truncate(u8, @intCast(u64, tmp)));
            break;
        }

        output.appendAssumeCapacity(@truncate(u8, @intCast(u64, (tmp & SEGMENT_BITS) | CONTINUE_BIT)));

        tmp = @intCast(i64, @bitCast(u64, tmp) >> 7); // unsigned right shift
    }

    return output.toOwnedSlice();
}

// Write a fixed-point number. Writes to a buffer.
pub fn writeFixedPointBuf(value: f32, buf: *[@sizeOf(f32)]u8) ![]const u8 {
    return writeBigBuf(i32, @floatToInt(i32, value / 32.0), buf);
}

// Write a fixed-point number. Allocates a buffer.
pub fn writeFixedPointAlloc(value: f32) ![]const u8 {
    return writeBigAlloc(i32, @floatToInt(i32, value / 32.0));
}

// Write any number in big-endian format. Writes to a buffer.
pub fn writeBigBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8) void {
    return writeInnerBuf(T, value, buf, .Big);
}

// Write any number in little-endian format. Writes to a buffer.
pub fn writeLittleBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8) void {
    return writeInnerBuf(T, value, buf, .Little);
}

// Write any number in big-endian format. Allocates a buffer.
pub fn writeBigAlloc(comptime T: type, value: T) ![]const u8 {
    return writeInnerAlloc(T, value, .Big);
}

// Write any number in little-endian format. Allocates a buffer.
pub fn writeLittleAlloc(comptime T: type, value: T) ![]const u8 {
    return writeInnerAlloc(T, value, .Little);
}

// Inner function used for writing. Writes to a buffer.
// std.mem.writeIntBig/Little is not used because it doesn't support floats.
fn writeInnerBuf(comptime T: type, value: T, buf: *[@sizeOf(T)]u8, endianness: std.builtin.Endian) void {
    const type_info = @typeInfo(T);

    if (type_info == .Int or type_info == .Float) {
        const size = @sizeOf(T);
        var bytes = @bitCast([size]u8, value);

        if (native_endian != endianness) {
            var i: usize = size;
            while (i > 0) : (i -= 1) buf.*[size - i] = bytes[i - 1];
        } else {
            buf.* = bytes;
        }
    } else {
        @compileError("bad input type");
    }
}

// Inner function used for writing. Allocates a buffer.
// std.mem.writeIntBig/Little is not used because it doesn't support floats.
inline fn writeInnerAlloc(comptime T: type, value: T, endianness: std.builtin.Endian) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, @sizeOf(T));
    writeInnerBuf(T, value, @constCast(buf.items[0..@sizeOf(T)]), endianness);
    return buf.toOwnedSlice();
}

// TESTS

test "read/write VarInt" {
    var written = try writeVarInt(5);
    var read_back = (try readVarInt(written))[0];

    try std.testing.expect(read_back == 5);
}

test "read/write VarLong" {
    var written = try writeVarLong(5);
    var read_back = (try readVarLong(written))[0];

    try std.testing.expect(read_back == 5);
}

test "read/write fixed-point" {
    var written = try writeFixedPointAlloc(32.0);
    var read_back = readFixedPoint(written);

    try std.testing.expect(read_back == 32.0);
}

test "read/write big-endian" {
    var written = try writeBigAlloc(isize, 5);
    var read_back = readBig(isize, written);

    try std.testing.expect(read_back == 5);
}

test "read/write little-endian" {
    var written = try writeLittleAlloc(usize, 5);
    var read_back = readLittle(usize, written);

    try std.testing.expect(read_back == 5);
}
