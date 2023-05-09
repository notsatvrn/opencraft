const std = @import("std");

const number = @import("number.zig");

const allocator = @import("../global.zig").allocator;

// https://wiki.vg/NBT
// Items in order, starting at 1.
pub const Value = union(enum) {
    byte: i8,
    short: i16,
    int: i32,
    long: i64,
    float: f32,
    double: f64,
    byte_array: []i8,
    string: []const u8,
    list: std.ArrayList(Value),
    compound: std.StringHashMap(Value),
    int_array: []i32,
    long_array: []i64,

    pub fn getTypeByte(self: Value) u8 {
        return switch (self) {
            Value.byte => 0x01,
            Value.short => 0x02,
            Value.int => 0x03,
            Value.long => 0x04,
            Value.float => 0x05,
            Value.double => 0x06,
            Value.byte_array => 0x07,
            Value.string => 0x08,
            Value.list => 0x09,
            Value.compound => 0x0A,
            Value.int_array => 0x0B,
            Value.long_array => 0x0C,
        };
    }

    pub fn getSize(self: Value) usize {
        return switch (self) {
            Value.byte => 1,
            Value.short => 2,
            Value.int => 4,
            Value.long => 8,
            Value.float => 4,
            Value.double => 8,
            Value.byte_array => |v| v.len,
            Value.string => |v| v.len,
            Value.list => |v| if (v.items.len > 0) v.items[0].getSize() * v.items.len else 0,
            Value.compound => |v| {
                var total: usize = 0;
                for (v.iter()) |kv| {
                    total += kv.key_ptr.len;
                    total += kv.value_ptr.getSize();
                }
                return total;
            },
            Value.int_array => |v| 4 * v.len,
            Value.long_array => |v| 8 * v.len,
        };
    }
};

pub const Tag = struct {
    name: []const u8,
    value: Value,

    pub fn read(bytes: []const u8, _: i32) Tag {
        var typ = bytes[0];
        var name_len = @intCast(usize, number.readBig(i16, bytes[1..3]));
        var name = bytes[3 .. 3 + name_len];
        var value_bytes = bytes[3 + name_len .. bytes.len];

        var value: Value = switch (typ) {
            0x01 => .{ .byte = @intCast(i8, value_bytes[0]) },
            0x02 => .{ .short = number.readBig(i16, value_bytes[0..2]) },
            0x03 => .{ .int = number.readBig(i32, value_bytes[0..4]) },
            0x04 => .{ .long = number.readBig(i64, value_bytes[0..8]) },
            0x05 => .{ .float = number.readBig(f32, value_bytes[0..4]) },
            0x06 => .{ .double = number.readBig(f64, value_bytes[0..8]) },
            0x07 => blk: {
                var len = @intCast(usize, number.readBig(i32, value_bytes[0..4]));
                break :blk .{ .byte_array = @ptrCast([]i8, @constCast(value_bytes[4 .. 4 + len])) };
            },
            0x08 => blk: {
                var len = @intCast(usize, number.readBig(i16, value_bytes[0..2]));
                break :blk .{ .string = value_bytes[2 .. 2 + len] };
            },
            else => .{ .byte = 0 }, // TODO
        };

        return .{
            .name = name,
            .value = value,
        };
    }

    pub fn write(self: Tag, _: i32) ![]const u8 {
        // capacity: byte length (for type) + short length (for name length) + name length (for name)
        var capacity = 1 + 2 + self.name.len;
        var buf = try std.ArrayList(u8).initCapacity(allocator, capacity);

        buf.appendAssumeCapacity(self.value.getTypeByte());

        number.writeBigBuf(i16, @intCast(i16, @truncate(u16, self.name.len)), @constCast(buf.items[1..3]));
        buf.items.len += 2;
        buf.appendSliceAssumeCapacity(self.name);

        switch (self.value) {
            Value.byte => |v| try buf.append(@intCast(u8, v)),
            Value.short => |v| number.writeBigBuf(i16, v, @constCast(buf.items[capacity .. capacity + 2])),
            Value.int => |v| number.writeBigBuf(i32, v, @constCast(buf.items[capacity .. capacity + 4])),
            Value.long => |v| number.writeBigBuf(i64, v, @constCast(buf.items[capacity .. capacity + 8])),
            Value.float => |v| number.writeBigBuf(f32, v, @constCast(buf.items[capacity .. capacity + 4])),
            Value.double => |v| number.writeBigBuf(f64, v, @constCast(buf.items[capacity .. capacity + 8])),
            Value.byte_array => |v| {
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @constCast(buf.items[capacity .. capacity + 4]));
                for (v) |byte| {
                    try buf.append(@intCast(u8, byte));
                }
            },
            Value.string => |v| {
                number.writeBigBuf(i16, @intCast(i16, @truncate(u16, v.len)), @constCast(buf.items[capacity .. capacity + 2]));
                try buf.appendSlice(v);
            },
            else => {}, // TODO
        }

        return buf.toOwnedSlice();
    }
};

test "serialize and deserialize" {
    const tag = Tag{
        .name = "int",
        .value = .{ .int = 5 },
    };

    var written = try tag.write(0);
    var read_back = Tag.read(written, 0);

    try std.testing.expect(std.mem.eql(u8, tag.name, read_back.name));
    try std.testing.expect(read_back.value.int == 5);
}
