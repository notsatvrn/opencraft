// Java Modified UTF-8 implementation based on TkTech's mutf8 Python library.

const std = @import("std");
var allocator = @import("../global.zig").allocator;

pub const MUTF8Error = error{
    NullByte,
    EarlyEnd,
    UnknownError,
};

// Decode Java Modified UTF-8 strings to UTF-8 strings.
pub fn decode(bytes: []const u8) ![]const u8 {
    const len = bytes.len;
    // pre-allocate len bytes and append w/ assumed capacity to minimize allocations.
    // length of output will always be less than len, so this is safe.
    var output = try std.ArrayList(u8).initCapacity(allocator, len);
    var i: usize = 0;
    var oi: usize = 0;

    while (i < len) : (oi += 1) {
        const b1 = bytes[i];
        i += 1;

        if (b1 == 0) {
            return MUTF8Error.NullByte;
        } else if (b1 < 0x80) {
            output.appendAssumeCapacity(b1);
        } else if ((b1 & 0xE0) == 0xC0) {
            if (i >= len) return MUTF8Error.EarlyEnd;
            output.appendAssumeCapacity((b1 & 0x1F) << 0x06 | (bytes[i] & 0x3F));
            i += 1;
        } else if ((b1 & 0xF0) == 0xE0) {
            if (i + 1 >= len) return MUTF8Error.EarlyEnd;

            const b2 = bytes[i];
            const b3 = bytes[i + 1];

            if (b1 == 0xED and (b2 & 0xF0) == 0xA0) {
                if (i + 4 >= len) return MUTF8Error.EarlyEnd;

                const b4 = bytes[i + 2];
                const b5 = bytes[i + 3];
                const b6 = bytes[i + 4];

                if (b4 == 0xED and (b5 & 0xF0) == 0xB0) {
                    output.appendAssumeCapacity(@intCast(@as(usize, 0x10000) |
                        @as(usize, b2 & 0x0F) << 0x10 |
                        @as(usize, b3 & 0x3F) << 0x0A |
                        @as(usize, b5 & 0x0F) << 0x06 |
                        @as(usize, b6 & 0x3F)));
                    i += 5;
                    continue;
                }
            }

            output.appendAssumeCapacity(@intCast(@as(usize, b1 & 0x0F) << 0x0C |
                @as(usize, b2 & 0x3F) << 0x06 |
                @as(usize, b3 & 0x3F)));
            i += 2;
        } else {
            return MUTF8Error.UnknownError;
        }
    }

    return output.toOwnedSlice();
}

// Decode UTF-8 strings to Java Modified UTF-8 strings.
// Catches and panics on OOM errors as they're the only errors.
pub fn encode(bytes: []const u8) []const u8 {
    // pre-allocate len * 6 bytes and append w/ assumed capacity to minimize allocations.
    // the 6 comes from the fact that this may serialize 6-byte surrogates.
    // maximum len can be is 65535 and 65535 * 6 < the 32-bit integer limit, so this is safe.
    var output = std.ArrayList(u8).initCapacity(allocator, bytes.len * 6) catch @panic("OOM");

    for (bytes) |byte| {
        if (byte == 0x00) {
            output.appendSliceAssumeCapacity(&[_]u8{ 0xC0, 0x80 });
        } else if (byte <= 0x7F) {
            output.appendAssumeCapacity(byte);
        } else if (byte <= 0x7FF) {
            output.appendSliceAssumeCapacity(&[_]u8{ (0xC0 | (0x1F & (byte >> 0x06))), (0x80 | (0x3F & byte)) });
        } else if (byte <= 0xFFFF) {
            output.appendSliceAssumeCapacity(&[_]u8{ (0xE0 | (0x0F & (byte >> 0x0C))), (0x80 | (0x3F & (byte >> 0x06))), (0x80 | (0x3F & byte)) });
        } else {
            output.appendSliceAssumeCapacity(&[_]u8{ 0xED, 0xA0 | ((byte >> 0x10) & 0x0F), 0x80 | ((byte >> 0x0A) & 0x3f), 0xED, 0xb0 | ((byte >> 0x06) & 0x0f), 0x80 | (byte & 0x3f) });
        }
    }

    return output.toOwnedSlice() catch @panic("OOM");
}
