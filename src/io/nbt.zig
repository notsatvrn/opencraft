// STATUS: writing done, reading unfinished

const std = @import("std");

const number = @import("number.zig");

var allocator = @import("../global.zig").allocator;

pub const NBTError = error{
    InvalidType,
    BufferTooSmall,
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

    pub inline fn fromByte(typ: u8) NBTError!Type {
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
// Complete wrapper around std.ArrayList with type checking.
// TODO: finish this
pub const List = struct {
    inner: std.ArrayList(Tag),
    typ: Type,

    pub inline fn init(typ: Type) List {
        return .{
            .inner = std.ArrayList(Tag).init(allocator),
            .typ = typ,
        };
    }

    pub inline fn initCapacity(typ: Type, num: usize) !List {
        return .{
            .inner = try std.ArrayList(Tag).initCapacity(allocator, num),
            .typ = typ,
        };
    }

    pub inline fn deinit(self: *List) void {
        self.inner.deinit();
    }

    pub inline fn append(self: *List, item: Tag) !void {
        if (@as(Type, item) != self.typ) return ListError.InvalidType;
        try self.inner.append(item);
    }

    pub inline fn appendAssumeCapacity(self: *List, item: Tag) !void {
        if (@as(Type, item) != self.typ) return ListError.InvalidType;
        self.inner.appendAssumeCapacity(item);
    }
};

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
            Tag.list => |v| blk: {
                var total: usize = 1 + 4; // type length + list length
                for (v.inner.items) |item| {
                    total += item.size();
                }
                break :blk total;
            },
            Tag.compound => |v| blk: {
                var iterator = v.iterator();
                var total: usize = 0;
                while (iterator.next()) |kv| {
                    // type length + name length + name + tag size
                    total += 1 + 2 + kv.key_ptr.len + kv.value_ptr.size();
                }
                break :blk total;
            },
            Tag.int_array => |v| 4 + (4 * v.len),
            Tag.long_array => |v| 4 + (8 * v.len),
        };
    }

    pub fn writeAlloc(self: Tag, version: i32) ![]const u8 {
        const len = self.size();
        var buf = try std.ArrayList(u8).initCapacity(allocator, len);
        buf.items.len = len;
        self.writeBufAssumeLength(version, buf.items);
        return buf.toOwnedSlice();
    }

    pub fn writeBuf(self: Tag, version: i32, buf: []u8) !void {
        if (buf.len < self.size()) return NBTError.BufferTooSmall;
        self.writeBufAssumeLength(version, buf);
    }

    pub fn writeBufAssumeLength(self: Tag, version: i32, buf: []u8) void {
        switch (self) {
            Tag.byte => |v| buf[0] = @bitCast(u8, v),
            Tag.short => |v| number.writeBigBuf(i16, v, @ptrCast(*[2]u8, buf[0..2])),
            Tag.int => |v| number.writeBigBuf(i32, v, @ptrCast(*[4]u8, buf[0..4])),
            Tag.long => |v| number.writeBigBuf(i64, v, @ptrCast(*[8]u8, buf[0..8])),
            Tag.float => |v| number.writeBigBuf(f32, v, @ptrCast(*[4]u8, buf[0..4])),
            Tag.double => |v| number.writeBigBuf(f64, v, @ptrCast(*[8]u8, buf[0..8])),
            Tag.byte_array => |v| {
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf[0..4]));
                for (v, 0..) |byte, i| buf[4 + i] = @bitCast(u8, byte);
            },
            Tag.string => |v| {
                number.writeBigBuf(i16, @intCast(i16, @truncate(u16, v.len)), @ptrCast(*[2]u8, buf[0..2]));
                for (v, 0..) |byte, i| buf[2 + i] = byte;
            },
            Tag.list => |v| {
                buf[0] = v.typ.toByte();
                var s: usize = 0;
                var e: usize = 0;
                for (v.inner.items) |item| {
                    e += item.size();
                    item.writeBufAssumeLength(version, buf[s..e]);
                    s = e;
                }
            },
            Tag.compound => |v| {
                var iterator = v.iterator();
                var s: usize = 0;
                var e: usize = 0;
                while (iterator.next()) |kv| {
                    const nt = NamedTag{
                        .name = kv.key_ptr.*,
                        .tag = kv.value_ptr.*,
                    };
                    e += nt.size();
                    nt.writeBufAssumeLength(version, buf[s..e]);
                    s = e;
                }
            },
            Tag.int_array => |v| {
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf[0..4]));
                for (v, 0..) |int, i| {
                    number.writeBigBuf(i32, int, @ptrCast(*[4]u8, buf[4 * (i + 1) .. 4 + (4 * (i + 1))]));
                }
            },
            Tag.long_array => |v| {
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.len)), @ptrCast(*[4]u8, buf[0..4]));
                for (v, 0..) |long, i| {
                    number.writeBigBuf(i64, long, @ptrCast(*[8]u8, buf[8 * (i + 1) .. 8 + (8 * (i + 1))]));
                }
            },
        }
    }
};

pub const NamedTag = struct {
    name: []const u8,
    tag: Tag,

    pub inline fn prefixSize(self: NamedTag) usize {
        // len: byte length (for type) + short length (for name) + name length
        return 1 + 2 + self.name.len;
    }

    pub inline fn size(self: NamedTag) usize {
        return self.prefixSize() + self.tag.size();
    }

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
                var list = try List.initCapacity(try Type.fromByte(tag_bytes[0]), @intCast(usize, number.readBig(i32, tag_bytes[1..5])));
                var i: usize = 0;
                var e: usize = 0;
                _ = e;
                while (i < tag_bytes.len) : (i += 1) {}
                break :blk .{ .list = list };
            },
            Type.compound => blk: { // TODO
                var compound = Compound.init(allocator);
                break :blk .{ .compound = compound };
            },
            Type.int_array => blk: {
                const len = @intCast(usize, number.readBig(i32, tag_bytes[0..4]));
                var array = try allocator.alloc(i32, len);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    array[i] = number.readBig(i32, tag_bytes[4 + (4 * i) .. 4 + (4 * (i + 1))]);
                }
                break :blk .{ .int_array = array };
            },
            Type.long_array => blk: {
                const len = @intCast(usize, number.readBig(i32, tag_bytes[0..4]));
                var array = try allocator.alloc(i64, len);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    array[i] = number.readBig(i64, tag_bytes[4 + (8 * i) .. 4 + (8 * (i + 1))]);
                }
                break :blk .{ .long_array = array };
            },
        };

        return .{
            .name = name,
            .tag = tag,
        };
    }

    pub inline fn writeAlloc(self: NamedTag, version: i32) ![]const u8 {
        const len = self.size();
        var buf = try std.ArrayList(u8).initCapacity(allocator, len);
        buf.items.len = len;
        self.writeBufAssumeLength(version, buf.items);
        return buf.toOwnedSlice();
    }

    pub fn writeBuf(self: NamedTag, version: i32, buf: []u8) !void {
        if (buf.len < self.size()) return NBTError.BufferTooSmall;
        self.writeBufAssumeLength(version, buf);
    }

    pub fn writeBufAssumeLength(self: NamedTag, version: i32, buf: []u8) void {
        buf[0] = self.tag.typeByte();
        number.writeBigBuf(i16, @intCast(i16, @truncate(u16, self.name.len)), @constCast(buf[1..3]));
        for (self.name, 0..) |byte, i| {
            buf[3 + i] = byte;
        }
        self.tag.writeBufAssumeLength(version, buf[self.prefixSize()..]);
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

    var written = try tag.writeAlloc(0);
    var read_back = try NamedTag.read(written, 0);

    try std.testing.expect(std.mem.eql(u8, tag.name, read_back.name));
    try std.testing.expect(read_back.tag.compound.get("key1").?.int == 5);
    try std.testing.expect(read_back.tag.compound.get("key2").?.long == 10);
}
