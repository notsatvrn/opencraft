const std = @import("std");
//const mutf8 = @import("mutf8.zig"); // TODO: modified UTF-8
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

pub const List = @import("../types/dynamic_list.zig").DynamicList(Tag, Type);
pub const Compound = std.StringHashMap(Tag);

fn readList(bytes: []const u8) anyerror!struct { List, usize } {
    const typ = try Type.fromByte(bytes[0]);
    const len = @intCast(usize, number.readBig(i32, bytes[1..5]));
    var list = try List.initCapacity(typ, len);

    if (len == 0) return .{ list, 5 };

    var s: usize = 5;
    var e: usize = s;
    var i: usize = 0;

    // using DynamicList allows us to do stuff like this:
    switch (typ) {
        Tag.byte, Tag.short, Tag.int, Tag.long, Tag.float, Tag.double => {
            const size = @as(usize, switch (typ) {
                Tag.byte => 1,
                Tag.short => 2,
                Tag.int => 4,
                Tag.long => 8,
                Tag.float => 4,
                Tag.double => 8,
                else => unreachable,
            });

            while (i < len) : (i += 1) {
                e += size;
                try list.appendAssumeCapacity(try Tag.read(bytes[s..e], typ));
                s = e;
            }
        },
        Tag.byte_array => {
            while (i < len) : (i += 1) {
                const array_length = @intCast(usize, number.readBig(i32, bytes[s .. s + 4]));
                e += 4 + array_length;
                try list.appendAssumeCapacity(try Tag.read(bytes[s..e], typ));
                s = e;
            }
        },
        Tag.string => {
            while (i < len) : (i += 1) {
                const array_length = @intCast(usize, number.readBig(i16, bytes[s .. s + 2]));
                s += 2; // array length size
                e += 2 + array_length;
                //try list.appendAssumeCapacity(.{ .string = try mutf8.decode(bytes[s..e]) }); // TODO: modified UTF-8
                try list.appendAssumeCapacity(.{ .string = bytes[s..e] });
                s = e;
            }
        },
        Tag.int_array, Tag.long_array => {
            const item_size = @as(usize, if (typ == Tag.int_array) 4 else 8);

            while (i < len) : (i += 1) {
                const array_length = @intCast(usize, number.readBig(i32, bytes[s .. s + 4]));
                e += 4 + (item_size * array_length);
                try list.appendAssumeCapacity(try Tag.read(bytes[s..e], typ));
                s = e;
            }
        },
        Type.compound => {
            while (i < len) : (i += 1) {
                const result = try readCompound(bytes[s..]);
                e = s + result[1] + 1;
                try list.appendAssumeCapacity(.{ .compound = result[0] });
                s = e;
            }
        },
        Type.list => {
            while (i < len) : (i += 1) {
                const result = try readList(bytes[s..]);
                e = s + result[1];
                try list.appendAssumeCapacity(.{ .list = result[0] });
                s = e;
            }
        },
    }

    return .{ list, e };
}

fn readCompound(bytes: []const u8) anyerror!struct { Compound, usize } {
    var compound = Compound.init(allocator);
    var s: usize = 0;
    var e: usize = 0;
    while (e < bytes.len and bytes[e] != 0) {
        const ityp = try Type.fromByte(bytes[s]);
        const name_len = @intCast(usize, number.readBig(i16, bytes[s + 1 .. s + 3]));
        s += 3;
        var name = bytes[s .. s + name_len];
        s += name_len;

        const tag: Tag = blk: {
            if (ityp != Type.compound and ityp != Type.list) {
                // finding the end: s + size.
                e = s + switch (ityp) {
                    Tag.byte => 1,
                    Tag.short => 2,
                    Tag.int => 4,
                    Tag.long => 8,
                    Tag.float => 4,
                    Tag.double => 8,
                    Tag.byte_array => 4 + @intCast(usize, number.readBig(i32, bytes[s .. s + 4])),
                    Tag.string => 2 + @intCast(usize, number.readBig(i16, bytes[s .. s + 2])),
                    Tag.int_array => 4 + (4 * @intCast(usize, number.readBig(i32, bytes[s .. s + 4]))),
                    Tag.long_array => 4 + (8 * @intCast(usize, number.readBig(i32, bytes[s .. s + 4]))),
                    else => unreachable,
                };

                break :blk try Tag.read(bytes[s..e], ityp);
            } else if (ityp == Type.compound) {
                const result = try readCompound(bytes[s..]);
                e = s + result[1] + 1;
                break :blk .{ .compound = result[0] };
            } else {
                const result = try readList(bytes[s..]);
                e = s + result[1];
                break :blk .{ .list = result[0] };
            }
        };

        try compound.put(name, tag);
        s = e;
    }
    return .{ compound, e };
}

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
            //Tag.string => |v| 2 + try mutf8.encode(v).len, TODO: modified UTF-8
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
                var total: usize = 1; // null
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

    pub fn read(bytes: []const u8, typ: Type) !Tag {
        return switch (typ) {
            Type.byte => .{ .byte = @bitCast(i8, bytes[0]) },
            Type.short => .{ .short = number.readBig(i16, bytes[0..2]) },
            Type.int => .{ .int = number.readBig(i32, bytes[0..4]) },
            Type.long => .{ .long = number.readBig(i64, bytes[0..8]) },
            Type.float => .{ .float = number.readBig(f32, bytes[0..4]) },
            Type.double => .{ .double = number.readBig(f64, bytes[0..8]) },
            Type.byte_array => blk: {
                var len = @intCast(usize, number.readBig(i32, bytes[0..4]));
                break :blk .{ .byte_array = @ptrCast([]i8, @constCast(bytes[4 .. 4 + len])) };
            },
            Type.string => blk: {
                var len = @intCast(usize, number.readBig(i16, bytes[0..2]));
                //break :blk .{ .string = try mutf8.decode(bytes[2 .. 2 + len]) }; // TODO: modified UTF-8
                break :blk .{ .string = bytes[2 .. 2 + len] };
            },
            Type.list => .{ .list = (try readList(bytes))[0] },
            Type.compound => .{ .compound = (try readCompound(bytes))[0] },
            Type.int_array => blk: {
                const len = @intCast(usize, number.readBig(i32, bytes[0..4]));
                var array = try allocator.alloc(i32, len);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    array[i] = number.readBig(i32, bytes[4 + (4 * i) .. 4 + (4 * (i + 1))]);
                }
                break :blk .{ .int_array = array };
            },
            Type.long_array => blk: {
                const len = @intCast(usize, number.readBig(i32, bytes[0..4]));
                var array = try allocator.alloc(i64, len);
                var i: usize = 0;
                while (i < len) : (i += 1) {
                    array[i] = number.readBig(i64, bytes[4 + (8 * i) .. 4 + (8 * (i + 1))]);
                }
                break :blk .{ .long_array = array };
            },
        };
    }

    pub inline fn writeAlloc(self: Tag) ![]const u8 {
        var buf = try allocator.alloc(u8, self.size());
        self.writeBufAssumeLength(buf);
        return buf;
    }

    pub inline fn writeBuf(self: Tag, buf: []u8) !void {
        if (buf.len < self.size()) return NBTError.BufferTooSmall;
        self.writeBufAssumeLength(buf);
    }

    pub fn writeBufAssumeLength(self: Tag, buf: []u8) void {
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
                //const encoded = try mutf8.encode(v); // TODO: modified UTF-8
                //for (encoded, 0..) |byte, i| buf[2 + i] = byte; // TODO: modified UTF-8
                for (v, 0..) |byte, i| buf[2 + i] = byte;
            },
            Tag.list => |v| {
                buf[0] = v.typ.toByte();
                number.writeBigBuf(i32, @intCast(i32, @truncate(u32, v.inner.items.len)), @ptrCast(*[4]u8, buf[1..5]));
                var s: usize = 5;
                var e: usize = s;
                for (v.inner.items) |item| {
                    e += item.size();
                    item.writeBufAssumeLength(buf[s..e]);
                    s = e;
                }
            },
            Tag.compound => |v| {
                var iterator = v.iterator();
                var s: usize = 0;
                var e: usize = s;
                while (iterator.next()) |kv| {
                    const nt = NamedTag{
                        .name = kv.key_ptr.*,
                        .tag = kv.value_ptr.*,
                    };
                    e += nt.size();
                    nt.writeBufAssumeLength(buf[s..e]);
                    s = e;
                }
                buf[e] = 0;
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

    pub inline fn read(bytes: []const u8) !NamedTag {
        var typ = try Type.fromByte(bytes[0]);
        var name_len = @intCast(usize, number.readBig(i16, bytes[1..3]));

        return .{
            .name = bytes[3 .. 3 + name_len],
            .tag = try Tag.read(bytes[3 + name_len ..], typ),
        };
    }

    pub inline fn writeAlloc(self: NamedTag) ![]const u8 {
        var buf = try allocator.alloc(u8, self.size());
        self.writeBufAssumeLength(buf);
        return buf;
    }

    pub inline fn writeBuf(self: NamedTag, buf: []u8) !void {
        if (buf.len < self.size()) return NBTError.BufferTooSmall;
        self.writeBufAssumeLength(buf);
    }

    pub inline fn writeBufAssumeLength(self: NamedTag, buf: []u8) void {
        buf[0] = self.tag.typeByte();
        number.writeBigBuf(i16, @intCast(i16, @truncate(u16, self.name.len)), @constCast(buf[1..3]));
        for (self.name, 0..) |byte, i| {
            buf[3 + i] = byte;
        }
        self.tag.writeBufAssumeLength(buf[self.prefixSize()..]);
    }
};

fn bigtest(output: NamedTag) !void {
    // test - root
    try std.testing.expect(output.tag == Tag.compound);
    try std.testing.expect(output.tag.compound.count() == 11);

    try std.testing.expect(output.tag.compound.contains("nested compound test"));
    try std.testing.expect(output.tag.compound.contains("intTest"));
    try std.testing.expect(output.tag.compound.contains("byteTest"));
    try std.testing.expect(output.tag.compound.contains("stringTest"));
    try std.testing.expect(output.tag.compound.contains("listTest (long)"));
    try std.testing.expect(output.tag.compound.contains("doubleTest"));
    try std.testing.expect(output.tag.compound.contains("floatTest"));
    try std.testing.expect(output.tag.compound.contains("longTest"));
    try std.testing.expect(output.tag.compound.contains("listTest (compound)"));
    try std.testing.expect(output.tag.compound.contains("byteArrayTest (the first 1000 values of (n*n*255+n*7)%100, starting with n=0 (0, 62, 34, 16, 8, ...))"));
    try std.testing.expect(output.tag.compound.contains("shortTest"));

    // test - "nested compound test"

    var nested_compound_test = output.tag.compound.get("nested compound test").?;
    try std.testing.expect(nested_compound_test == Tag.compound);
    try std.testing.expect(nested_compound_test.compound.count() == 2);
    try std.testing.expect(nested_compound_test.compound.contains("egg"));
    try std.testing.expect(nested_compound_test.compound.contains("ham"));

    var nested_compound_test_egg = nested_compound_test.compound.get("egg").?;
    try std.testing.expect(nested_compound_test_egg == Tag.compound);
    try std.testing.expect(nested_compound_test_egg.compound.count() == 2);
    try std.testing.expect(nested_compound_test_egg.compound.contains("name"));
    try std.testing.expect(nested_compound_test_egg.compound.contains("value"));

    var nested_compound_test_egg_name = nested_compound_test_egg.compound.get("name").?;
    try std.testing.expect(nested_compound_test_egg_name == Tag.string);
    try std.testing.expect(std.mem.eql(u8, nested_compound_test_egg_name.string, "Eggbert"));

    var nested_compound_test_egg_value = nested_compound_test_egg.compound.get("value").?;
    try std.testing.expect(nested_compound_test_egg_value == Tag.float);
    try std.testing.expect(nested_compound_test_egg_value.float == 0.5);

    var nested_compound_test_ham = nested_compound_test.compound.get("ham").?;
    try std.testing.expect(nested_compound_test_ham == Tag.compound);
    try std.testing.expect(nested_compound_test_ham.compound.count() == 2);
    try std.testing.expect(nested_compound_test_ham.compound.contains("name"));
    try std.testing.expect(nested_compound_test_ham.compound.contains("value"));

    var nested_compound_test_ham_name = nested_compound_test_ham.compound.get("name").?;
    try std.testing.expect(nested_compound_test_ham_name == Tag.string);
    try std.testing.expect(std.mem.eql(u8, nested_compound_test_ham_name.string, "Hampus"));

    var nested_compound_test_ham_value = nested_compound_test_ham.compound.get("value").?;
    try std.testing.expect(nested_compound_test_ham_value == Tag.float);
    try std.testing.expect(nested_compound_test_ham_value.float == 0.75);

    // test - "listTest (long)"

    var list_test_long = output.tag.compound.get("listTest (long)").?;
    try std.testing.expect(list_test_long == Tag.list);
    try std.testing.expect(list_test_long.list.typ == Type.long);
    try std.testing.expect(list_test_long.list.inner.items.len == 5);
    try std.testing.expect(list_test_long.list.inner.items[0] == Tag.long);
    try std.testing.expect(list_test_long.list.inner.items[1] == Tag.long);
    try std.testing.expect(list_test_long.list.inner.items[2] == Tag.long);
    try std.testing.expect(list_test_long.list.inner.items[3] == Tag.long);
    try std.testing.expect(list_test_long.list.inner.items[4] == Tag.long);
    try std.testing.expect(list_test_long.list.inner.items[0].long == 11);
    try std.testing.expect(list_test_long.list.inner.items[1].long == 12);
    try std.testing.expect(list_test_long.list.inner.items[2].long == 13);
    try std.testing.expect(list_test_long.list.inner.items[3].long == 14);
    try std.testing.expect(list_test_long.list.inner.items[4].long == 15);

    // test - "listTest (compound)"

    var list_test_compound = output.tag.compound.get("listTest (compound)").?;
    try std.testing.expect(list_test_compound == Tag.list);
    try std.testing.expect(list_test_compound.list.typ == Type.compound);
    try std.testing.expect(list_test_compound.list.inner.items.len == 2);
    try std.testing.expect(list_test_compound.list.inner.items[0] == Tag.compound);
    try std.testing.expect(list_test_compound.list.inner.items[1] == Tag.compound);

    var list_test_compound_0 = list_test_compound.list.inner.items[0];
    try std.testing.expect(list_test_compound_0 == Tag.compound);
    try std.testing.expect(list_test_compound_0.compound.count() == 2);
    try std.testing.expect(list_test_compound_0.compound.contains("created-on"));
    try std.testing.expect(list_test_compound_0.compound.contains("name"));

    var list_test_compound_0_created_on = list_test_compound_0.compound.get("created-on").?;
    try std.testing.expect(list_test_compound_0_created_on == Tag.long);
    try std.testing.expect(list_test_compound_0_created_on.long == 1264099775885);

    var list_test_compound_0_name = list_test_compound_0.compound.get("name").?;
    try std.testing.expect(list_test_compound_0_name == Tag.string);
    try std.testing.expect(std.mem.eql(u8, list_test_compound_0_name.string, "Compound tag #0"));

    var list_test_compound_1 = list_test_compound.list.inner.items[1];
    try std.testing.expect(list_test_compound_1 == Tag.compound);
    try std.testing.expect(list_test_compound_1.compound.count() == 2);
    try std.testing.expect(list_test_compound_1.compound.contains("created-on"));
    try std.testing.expect(list_test_compound_1.compound.contains("name"));

    var list_test_compound_1_created_on = list_test_compound_1.compound.get("created-on").?;
    try std.testing.expect(list_test_compound_1_created_on == Tag.long);
    try std.testing.expect(list_test_compound_1_created_on.long == 1264099775885);

    var list_test_compound_1_name = list_test_compound_1.compound.get("name").?;
    try std.testing.expect(list_test_compound_1_name == Tag.string);
    try std.testing.expect(std.mem.eql(u8, list_test_compound_1_name.string, "Compound tag #1"));

    // test - other

    var int_test = output.tag.compound.get("intTest").?;
    try std.testing.expect(int_test == Tag.int);
    try std.testing.expect(int_test.int == 2147483647);

    var byte_test = output.tag.compound.get("byteTest").?;
    try std.testing.expect(byte_test == Tag.byte);
    try std.testing.expect(byte_test.byte == 127);

    var string_test = output.tag.compound.get("stringTest").?;
    try std.testing.expect(string_test == Tag.string);
    //try std.testing.expect(std.mem.eql(u8, string_test.string, "HELLO WORLD THIS IS A TEST STRING \xc5\xc4\xd6!")); // TODO: modified UTF-8
    try std.testing.expect(std.mem.eql(u8, string_test.string, "HELLO WORLD THIS IS A TEST STRING ÅÄÖ!"));

    var double_test = output.tag.compound.get("doubleTest").?;
    try std.testing.expect(double_test == Tag.double);
    try std.testing.expect(double_test.double == 0.49312871321823148);

    var float_test = output.tag.compound.get("floatTest").?;
    try std.testing.expect(float_test == Tag.float);
    try std.testing.expect(float_test.float == 0.49823147058486938);

    var long_test = output.tag.compound.get("longTest").?;
    try std.testing.expect(long_test == Tag.long);
    try std.testing.expect(long_test.long == 9223372036854775807);

    var short_test = output.tag.compound.get("shortTest").?;
    try std.testing.expect(short_test == Tag.short);
    try std.testing.expect(short_test.short == 32767);
}

test "bigtest.nbt" {
    //allocator = std.testing.allocator;

    var in_stream = std.io.fixedBufferStream(@embedFile("bigtest.nbt"));
    var gzip_stream = try std.compress.gzip.decompress(allocator, in_stream.reader());
    defer gzip_stream.deinit();
    const buf = try gzip_stream.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(buf);
    var output = try NamedTag.read(buf);

    try bigtest(output);

    const rewritten = try output.writeAlloc();
    defer allocator.free(rewritten);
    var rewritten_output = try NamedTag.read(rewritten);

    try bigtest(rewritten_output);
}
