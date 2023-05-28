const std = @import("std");

const number = @import("number.zig");

var allocator = @import("../global.zig").allocator;

pub const NBTError = error{
    InvalidType,
    InconsistentListType,
};

// https://wiki.vg/NBT
// Items in order, starting at 1.
pub const Type = enum {
    byte,
    short,
    int,
    long,
    float,
    double,
    byte_array,
    string,
    list,
    compound,
    int_array,
    long_array,

    pub inline fn fromByte(typ: u8) !Type {
        if (typ == 0x00 or typ > 0x0C) return NBTError.InvalidType;
        return @intToEnum(Type, typ - 1);
    }

    pub inline fn toByte(self: Type) u8 {
        return @as(u8, @enumToInt(self) + 1);
    }
};

pub const ListError = error{
    InvalidType,
};

// *sigh*
pub const ListWIP = struct {
    inner: std.ArrayList(Tag),
    typ_name: [:0]const u8,

    pub inline fn init(typ: Type) ListWIP {
        return .{
            .inner = std.ArrayList(Tag).init(allocator),
            .typ_name = @tagName(typ),
        };
    }

    pub inline fn initCapacity(typ: Type, num: usize) !ListWIP {
        return .{
            .inner = try std.ArrayList(Tag).initCapacity(allocator, num),
            .typ_name = @tagName(typ),
        };
    }

    pub inline fn deinit(self: *ListWIP) void {
        self.inner.deinit();
    }

    pub inline fn append(self: *ListWIP, item: Tag) !void {
        if (!std.mem.eql(u8, @tagName(item), self.typ_name)) return ListError.InvalidType;
        try self.inner.append(item);
    }

    pub inline fn appendAssumeCapacity(self: *ListWIP, item: Tag) !void {
        if (!std.mem.eql(u8, @tagName(item), self.typ_name)) return ListError.InvalidType;
        self.inner.appendAssumeCapacity(item);
    }
};

pub const List = std.ArrayList(Tag);
pub const Compound = std.StringHashMap(Tag);

pub const Tag = union(Type) {
    byte: i8,
    short: i16,
    int: i32,
    long: i64,
    float: f32,
    double: f64,
    byte_array: []i8,
    string: []const u8,
    list: List,
    compound: Compound,
    int_array: []i32,
    long_array: []i64,

    pub inline fn deinit(self: *Tag) void {
        switch (self) {
            Tag.list => |v| v.deinit(),
            Tag.compound => |v| v.deinit(),
            else => {},
        }
    }

    pub inline fn typeByte(self: Tag) u8 {
        return @as(Type, self).toByte();
    }

    pub fn size(self: Tag) usize {
        return switch (self) {
            Tag.byte => 1,
            Tag.short => 2,
            Tag.int => 4,
            Tag.long => 8,
            Tag.float => 4,
            Tag.double => 8,
            Tag.byte_array => |v| 4 + v.len,
            Tag.string => |v| 2 + v.len,
            Tag.list => |v| if (v.items.len > 0) v.items[0].size() * v.items.len else 0,
            Tag.compound => |v| {
                var iterator = v.iterator();
                var total: usize = 0;
                while (iterator.next()) |kv| {
                    // type length + name length + name + tag size + null
                    total += 1 + 2 + kv.key_ptr.len + kv.value_ptr.size() + 1;
                }
                return total;
            },
            Tag.int_array => |v| 4 + (4 * v.len),
            Tag.long_array => |v| 4 + (8 * v.len),
        };
    }
};

pub const NamedTag = struct {
    name: []const u8,
    tag: Tag,

    pub fn read(bytes: []const u8, _: i32) !NamedTag {
        var typ = try Type.fromByte(bytes[0]);
        var name_len = @intCast(usize, number.readBig(i16, bytes[1..3]));
        var name = bytes[3 .. 3 + name_len];
        var tag_bytes = bytes[3 + name_len .. bytes.len];

        var tag: Tag = switch (typ) {
            Type.byte => .{ .byte = @bitCast(i8, tag_bytes[0]) },
            Type.short => .{ .short = number.readBig(i16, tag_bytes[0..2]) },
            Type.int => .{ .int = number.readBig(i32, tag_bytes[0..4]) },
            Type.long => .{ .long = number.readBig(i64, tag_bytes[0..8]) },
            Type.float => .{ .float = number.readBig(f32, tag_bytes[0..4]) },
            Type.double => .{ .double = number.readBig(f64, tag_bytes[0..8]) },
            Type.byte_array => blk: {
                var len = @intCast(usize, number.readBig(i32, tag_bytes[0..4]));
                break :blk .{ .byte_array = @ptrCast([]i8, @constCast(tag_bytes[4 .. 4 + len])) };
            },
            Type.string => blk: {
                var len = @intCast(usize, number.readBig(i16, tag_bytes[0..2]));
                break :blk .{ .string = tag_bytes[2 .. 2 + len] };
            },
            Type.list => blk: { // TODO
                var list = List.init(allocator);
                break :blk .{ .list = list };
            },
            Type.compound => blk: { // TODO
                var compound = Compound.init(allocator);
                break :blk .{ .compound = compound };
            },
            Type.int_array => blk: {
                var len = @intCast(usize, number.readBig(i32, tag_bytes[0..4]));
                break :blk .{ .int_array = @ptrCast([]i32, @constCast(tag_bytes[4 .. 4 + (4 * len)])) };
            },
            Type.long_array => blk: {
                var len = @intCast(usize, number.readBig(i32, tag_bytes[0..4]));
                break :blk .{ .long_array = @ptrCast([]i64, @constCast(tag_bytes[4 .. 4 + (8 * len)])) };
            },
        };

        return .{
            .name = name,
            .tag = tag,
        };
    }

    pub fn write(self: NamedTag, version: i32) ![]const u8 {
        // capacity: byte length (for type) + short length (for name length) + name length (for name)
        // ^^^ add tag size to this but only when initializing (code depends on pre-tag area size)
        // pre-allocating all of this for improved performance
        var tag_size = self.tag.size();
        var capacity = 1 + 2 + self.name.len;
        var buf = try std.ArrayList(u8).initCapacity(allocator, capacity + tag_size);

        buf.appendAssumeCapacity(self.tag.typeByte());

        buf.items.len += 2;
        number.writeBigBuf(i16, @intCast(i16, @truncate(u16, self.name.len)), @constCast(buf.items[1..3]));

        buf.appendSliceAssumeCapacity(self.name);

        switch (self.tag) {
            Tag.byte => |v| buf.appendAssumeCapacity(@bitCast(u8, v)),
            Tag.short => |v| {
                buf.items.len += 2;
                number.writeBigBuf(i16, v, @ptrCast(*[2]u8, buf.items[capacity .. capacity + 2]));
            },
            Tag.int => |v| {
                buf.items.len += 4;
                number.writeBigBuf(i32, v, @ptrCast(*[4]u8, buf.items[capacity .. capacity + 4]));
            },
            Tag.long => |v| {
                buf.items.len += 8;
                number.writeBigBuf(i64, v, @ptrCast(*[8]u8, buf.items[capacity .. capacity + 8]));
            },
            Tag.float => |v| {
                buf.items.len += 4;
                number.writeBigBuf(f32, v, @ptrCast(*[4]u8, buf.items[capacity .. capacity + 4]));
            },
            Tag.double => |v| {
                buf.items.len += 8;
                number.writeBigBuf(f64, v, @ptrCast(*[8]u8, buf.items[capacity .. capacity + 8]));
            },
            Tag.byte_array => |v| {
                buf.items.len += 4;
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf.items[capacity .. capacity + 4]));
                for (v) |byte| {
                    buf.appendAssumeCapacity(@bitCast(u8, byte));
                }
            },
            Tag.string => |v| {
                buf.items.len += 2;
                number.writeBigBuf(i16, @intCast(i16, @truncate(u16, v.len)), @ptrCast(*[2]u8, buf.items[capacity .. capacity + 2]));
                buf.appendSliceAssumeCapacity(v);
            },
            Tag.list => |v| {
                var typ = "";

                for (v.items, 0..) |item, i| {
                    if (i == 0) {
                        typ = @tagName(item);
                    } else if (!std.mem.eql(u8, @tagName(item), typ)) {
                        return NBTError.InconsistentListType; // TODO: add list type and avoid doing this
                    }
                }
            },
            Tag.compound => |v| {
                var iterator = v.iterator();

                while (iterator.next()) |kv| {
                    buf.appendSliceAssumeCapacity(try (NamedTag{
                        .name = kv.key_ptr.*,
                        .tag = kv.value_ptr.*,
                    }).write(version));

                    buf.appendAssumeCapacity(0);
                }
            },
            Tag.int_array => |v| {
                buf.items.len += 4;
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf.items[capacity .. capacity + 4]));
                for (v, 0..) |int, i| {
                    buf.items.len += 4;
                    number.writeBigBuf(i32, int, @ptrCast(*[4]u8, buf.items[capacity + (4 * i) .. capacity + 4 + (4 * i)]));
                }
            },
            Tag.long_array => |v| {
                buf.items.len += 4;
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf.items[capacity .. capacity + 4]));
                for (v, 0..) |long, i| {
                    buf.items.len += 8;
                    number.writeBigBuf(i64, long, @ptrCast(*[8]u8, buf.items[capacity + (8 * i) .. capacity + 8 + (8 * i)]));
                }
            },
        }

        return buf.toOwnedSlice();
    }
};

test "serialize and deserialize" {
    allocator = std.testing.allocator;

    const tag = NamedTag{
        .name = "compound_example",
        .tag = .{ .compound = blk: {
            var compound = Compound.init(allocator);
            try compound.put("key1", .{ .int = 5 });
            try compound.put("key2", .{ .long = 10 });
            break :blk compound;
        } },
    };

    std.debug.print("{}", .{@intCast(i16, @truncate(u16, @as(usize, 5)))});

    var written = try tag.write(0);
    var read_back = try NamedTag.read(written, 0);

    try std.testing.expect(std.mem.eql(u8, tag.name, read_back.name));
    try std.testing.expect(read_back.tag.compound.get("key1").?.int == 5);
    try std.testing.expect(read_back.tag.compound.get("key2").?.long == 10);
}
