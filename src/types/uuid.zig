const std = @import("std");

// Largely based on https://github.com/dmgk/zig-uuid.
// Some functions also based on https://github.com/AdoptOpenJDK/openjdk-jdk8u/blob/master/jdk/src/share/classes/java/util/UUID.java.

pub const Error = error{
    InvalidUUID,
};

pub const UUID = struct {
    bytes: [16]u8,

    // Initialize a UUID from an array of bytes by hashing them with MD5 (UUID v3).
    pub fn initFromBytes(bytes: []const u8) UUID {
        var uuid = UUID{ .bytes = undefined };

        std.crypto.hash.Md5.hash(bytes, &uuid.bytes, .{});

        uuid.bytes[6] = (uuid.bytes[6] & 0x0f) | 0x30;
        uuid.bytes[8] = (uuid.bytes[8] & 0x3f) | 0x80;

        return uuid;
    }

    // Initialize a UUID from random bytes (UUID v4).
    pub fn initRandom() UUID {
        var uuid = UUID{ .bytes = undefined };

        std.crypto.random.bytes(&uuid.bytes);

        uuid.bytes[6] = (uuid.bytes[6] & 0x0f) | 0x40;
        uuid.bytes[8] = (uuid.bytes[8] & 0x3f) | 0x80;

        return uuid;
    }

    // Indices in the UUID string representation for each byte.
    const encoded_pos = [16]u8{ 0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 };

    // Hex to nibble mapping.
    const hex_to_nibble = [256]u8{
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    };

    // Format UUID.
    pub fn format(
        self: UUID,
        comptime layout: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options; // currently unused

        if (layout.len != 0 and layout[0] != 's')
            @compileError("Unsupported format specifier for UUID type: '" ++ layout ++ "'.");

        var buf: [36]u8 = undefined;
        const hex = "0123456789abcdef";

        buf[8] = '-';
        buf[13] = '-';
        buf[18] = '-';
        buf[23] = '-';
        inline for (encoded_pos, 0..) |i, j| {
            buf[i + 0] = hex[self.bytes[j] >> 4];
            buf[i + 1] = hex[self.bytes[j] & 0x0f];
        }

        try std.fmt.format(writer, "{s}", .{buf});
    }

    // Parse UUID from string.
    pub fn parse(buf: []const u8) Error!UUID {
        var uuid = UUID{ .bytes = undefined };

        if (buf.len != 36 or buf[8] != '-' or buf[13] != '-' or buf[18] != '-' or buf[23] != '-')
            return Error.InvalidUUID;

        inline for (encoded_pos, 0..) |i, j| {
            const hi = hex_to_nibble[buf[i + 0]];
            const lo = hex_to_nibble[buf[i + 1]];
            if (hi == 0xff or lo == 0xff) {
                return Error.InvalidUUID;
            }
            uuid.bytes[j] = hi << 4 | lo;
        }

        return uuid;
    }

    // Convert to 2x big-endian 64-bit integers.
    pub fn toI64Array(self: UUID) [2]i64 {
        var output = [2]i64{ 0, 0 }; // MSB, LSB
        var i: usize = 0;
        while (i < 8) : (i += 1) output[0] = (output[0] << 8) | (self.bytes[i] & 0xff);
        while (i < 16) : (i += 1) output[1] = (output[1] << 8) | (self.bytes[i] & 0xff);
        return output;
    }

    // Serialize to bytes as 2x 64-bit integers.
    pub fn serialize(self: UUID, _: i32) []u8 {
        var output = [1]u8{0} ** 16;
        var ints = self.toI64Array();
        output[0] = (ints[0] >> 56) & 0xff;
        output[1] = (ints[0] >> 48) & 0xff;
        output[2] = (ints[0] >> 40) & 0xff;
        output[3] = (ints[0] >> 32) & 0xff;
        output[4] = (ints[0] >> 24) & 0xff;
        output[5] = (ints[0] >> 16) & 0xff;
        output[6] = (ints[0] >> 8) & 0xff;
        output[7] = ints[0] & 0xff;
        output[8] = (ints[1] >> 56) & 0xff;
        output[9] = (ints[1] >> 48) & 0xff;
        output[10] = (ints[1] >> 40) & 0xff;
        output[11] = (ints[1] >> 32) & 0xff;
        output[12] = (ints[1] >> 24) & 0xff;
        output[13] = (ints[1] >> 16) & 0xff;
        output[14] = (ints[1] >> 8) & 0xff;
        output[15] = ints[1] & 0xff;
        return &output;
    }
};

test "parse and format" {
    const uuids = [_][]const u8{
        "d0cd8041-0504-40cb-ac8e-d05960d205ec",
        "3df6f0e4-f9b1-4e34-ad70-33206069b995",
        "f982cf56-c4ab-4229-b23c-d17377d000be",
        "6b9f53be-cf46-40e8-8627-6b60dc33def8",
        "c282ec76-ac18-4d4a-8a29-3b94f5c74813",
        "00000000-0000-0000-0000-000000000000",
    };

    for (uuids) |uuid| {
        try std.testing.expectFmt(uuid, "{}", .{try UUID.parse(uuid)});
    }
}

test "invalid UUID" {
    const uuids = [_][]const u8{
        "3df6f0e4-f9b1-4e34-ad70-33206069b99", // too short
        "3df6f0e4-f9b1-4e34-ad70-33206069b9912", // too long
        "3df6f0e4-f9b1-4e34-ad70_33206069b9912", // missing or invalid group separator
        "zdf6f0e4-f9b1-4e34-ad70-33206069b995", // invalid character
    };

    for (uuids) |uuid| {
        try std.testing.expectError(Error.InvalidUUID, UUID.parse(uuid));
    }
}
