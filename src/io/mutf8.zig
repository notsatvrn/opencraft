const std = @import("std");
var allocator = @import("../global.zig").allocator;

pub const MUTF8Error = error{
    NullByte,
    EarlyEnd,
    UnknownError,
};

pub fn decode(bytes: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    const len = bytes.len;
    var i: usize = 0;

    while (i < len) {
        const b1 = bytes[i];
        i += 1;

        if (b1 == 0) {
            return MUTF8Error.NullByte;
        } else if (b1 < 0x80) {
            try output.append(b1);
        } else if ((b1 & 0xE0) == 0xC0) {
            if (i >= len) return MUTF8Error.EarlyEnd;

            try output.append((b1 & 0x1F) << 0x06 | (bytes[i] & 0x3F));
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
                    try output.append(@truncate(u8, @as(usize, 0x10000) |
                        @as(usize, b2 & 0x0F) << 0x10 |
                        @as(usize, b3 & 0x3F) << 0x0A |
                        @as(usize, b5 & 0x0F) << 0x06 |
                        @as(usize, b6 & 0x3F)));
                    i += 5;
                    continue;
                }
            }

            try output.append(@truncate(u8, @as(usize, b1 & 0x0F) << 0x0C |
                @as(usize, b2 & 0x3F) << 0x06 |
                @as(usize, b3 & 0x3F)));

            i += 2;
        } else {
            return MUTF8Error.UnknownError;
        }
    }

    return output.toOwnedSlice();
}

pub fn encode(bytes: []const u8) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);

    for (bytes) |byte| {
        if (byte == 0x00) {
            try try output.appendSlice([]const u8{ 0xC0, 0x80 });
        } else if (byte <= 0x7F) {
            try try output.append(byte);
        } else if (byte <= 0x7FF) {
            try try output.appendSlice([]const u8{ (0xC0 | (0x1F & (byte >> 0x06))), (0x80 | (0x3F & byte)) });
        } else if (byte <= 0xFFFF) {
            try try output.appendSlice([]const u8{ (0xE0 | (0x0F & (byte >> 0x0C))), (0x80 | (0x3F & (byte >> 0x06))), (0x80 | (0x3F & byte)) });
        } else {
            try try output.appendSlice([]const u8{ 0xED, 0xA0 | ((byte >> 0x10) & 0x0F), 0x80 | ((byte >> 0x0A) & 0x3f), 0xED, 0xb0 | ((byte >> 0x06) & 0x0f), 0x80 | (byte & 0x3f) });
        }
    }

    return output.toOwnedSlice();
}
