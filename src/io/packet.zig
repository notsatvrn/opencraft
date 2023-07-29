const std = @import("std");

const io = @import("../io.zig");
const types = @import("../types.zig");
const number = @import("number.zig");

var allocator = @import("../global.zig").allocator;

pub const ArrayItemType = enum {
    VarNum,
};

pub const Writer = struct {
    version: u16,
    buffer: std.ArrayList(u8),

    pub inline fn init(version: u16) !Writer {
        return .{
            .version = version,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub inline fn deinit(self: *Writer) void {
        self.buffer.deinit();
    }

    pub inline fn finish(self: *Writer) ![]const u8 {
        return self.buffer.toOwnedSlice();
    }

    pub inline fn writeBoolean(self: *Writer, b: bool) !void {
        return if (b) self.buffer.append(0x01) else self.buffer.append(0x00);
    }

    pub inline fn writeByte(self: *Writer, b: i8) !void {
        try self.buffer.append(@bitCast(b));
    }

    pub inline fn writeUnsignedByte(self: *Writer, ub: u8) !void {
        try self.buffer.append(ub);
    }

    pub inline fn writeShort(self: *Writer, s: i16) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(i16, s));
    }

    pub inline fn writeUnsignedShort(self: *Writer, us: u16) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(u16, us));
    }

    pub inline fn writeInt(self: *Writer, i: i32) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(i32, i));
    }

    pub inline fn writeLong(self: *Writer, l: i64) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(i64, l));
    }

    pub inline fn writeFloat(self: *Writer, f: f32) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(f32, f));
    }

    pub inline fn writeDouble(self: *Writer, d: f64) !void {
        try self.buffer.appendSlice(number.writeBigAlloc(f64, d));
    }

    pub inline fn writeString(self: *Writer, string: []const u8) !void {
        try self.buffer.appendSlice(number.writeBigAllocVarInt(@as(i32, string.len)));
        try self.buffer.appendSlice(string);
    }

    pub inline fn writeVarInt(self: *Writer, i: i32) !void {
        try self.buffer.appendSlice(number.writeBigVarInt(i));
    }

    pub inline fn writeVarLong(self: *Writer, l: i64) !void {
        try self.buffer.appendSlice(number.writeBigVarLong(l));
    }

    //pub inline fn writeEntityMetadata(self: *Writer, metadata: types.EntityMetadata) !void {
    //    try self.buffer.appendSlice(metadata.write(self.version));
    //}

    //pub inline fn writeSlot(self: *Writer, slot: types.Slot) !void {
    //    try self.buffer.appendSlice(slot.write(self.version));
    //}

    pub inline fn writeTag(self: *Writer, nbt: io.nbt.Tag) !void {
        try self.buffer.appendSlice(nbt.writeAlloc());
    }

    pub inline fn writeNamedTag(self: *Writer, nbt: io.nbt.NamedTag) !void {
        try self.buffer.appendSlice(nbt.writeAlloc());
    }

    pub inline fn writePosition(self: *Writer, pos: types.Vec3i) !void {
        try self.buffer.appendSlice(pos.write(self.version));
    }

    pub inline fn writeUUID(self: *Writer, uuid: types.UUID) !void {
        try self.buffer.appendSlice(uuid.bytes);
    }

    pub fn writeArray(self: *Writer, comptime T: type, item_type: ?ArrayItemType, array: []T) !void {
        var i: usize = 0;

        switch (T) {
            bool => while (i < array.len) : (i += 1) self.writeBoolean(array[i]),
            i8 => while (i < array.len) : (i += 1) self.writeByte(array[i]),
            u8 => while (i < array.len) : (i += 1) self.writeUnsignedByte(array[i]),
            i16 => while (i < array.len) : (i += 1) self.writeShort(array[i]),
            u16 => while (i < array.len) : (i += 1) self.writeUnsignedShort(array[i]),
            i32 => if (item_type != null and item_type.? == .VarNum) {
                while (i < array.len) : (i += 1) self.writeVarInt(array[i]);
            } else {
                while (i < array.len) : (i += 1) self.writeInt(array[i]);
            },
            i64 => if (item_type != null and item_type.? == .VarNum) {
                while (i < array.len) : (i += 1) self.writeVarLong(array[i]);
            } else {
                while (i < array.len) : (i += 1) self.writeLong(array[i]);
            },
            f32 => while (i < array.len) : (i += 1) self.writeFloat(array[i]),
            f64 => while (i < array.len) : (i += 1) self.writeDouble(array[i]),
            []const u8 => while (i < array.len) : (i += 1) self.writeString(array[i]),
            else => if (@hasDecl(T, "write")) {
                self.buffer.appendSlice(array[i].write(self.version));
            } else {
                @compileError("bad array item type");
            },
        }
    }
};

pub const ReaderError = error{
    end_of_data,
};

pub const Reader = struct {
    version: u16 = 0,
    position: usize = 0,
    buffer: std.ArrayList(u8),

    pub inline fn init(version: u16, data: []const u8) !Reader {
        return .{
            .version = version,
            .buffer = std.ArrayList(u8).fromOwnedSlice(allocator, data),
        };
    }

    pub inline fn reset(self: *Reader, data: []const u8) void {
        self.version = 0;
        self.position = 0;
        self.buffer.clearRetainingCapacity();
        self.buffer.appendSlice(data);
        self.buffer.shrinkAndFree(data.len);
    }

    pub inline fn deinit(self: *Reader) void {
        self.version = 0;
        self.position = 0;
        self.buffer.deinit();
    }

    pub inline fn advance(self: *Reader, n: usize) !void {
        self.position += n;
        if (self.buffer.items.len >= self.position) return ReaderError.end_of_data;
    }

    pub inline fn readBoolean(self: *Reader) !bool {
        try self.advance(1);
        return self.buffer.items[self.position - 1] != 0x00;
    }

    pub inline fn readByte(self: *Reader) !i8 {
        try self.advance(1);
        return @bitCast(self.buffer.items[self.position - 1]);
    }

    pub inline fn readUnsignedByte(self: *Reader) !u8 {
        try self.advance(1);
        return self.buffer.items[self.position - 1];
    }

    pub inline fn readShort(self: *Reader) !i16 {
        try self.advance(2);
        return number.readBig(i16, self.buffer.items[self.position - 2 .. self.position + 1]);
    }

    pub inline fn readUnsignedShort(self: *Reader) !u16 {
        try self.advance(2);
        return number.readBig(u16, self.buffer.items[self.position - 2 .. self.position + 1]);
    }

    pub inline fn readInt(self: *Reader) !i32 {
        try self.advance(4);
        return number.readBig(i32, self.buffer.items[self.position - 4 .. self.position + 1]);
    }

    pub inline fn readLong(self: *Reader) !i64 {
        try self.advance(8);
        return number.readBig(i64, self.buffer.items[self.position - 8 .. self.position + 1]);
    }

    pub inline fn readFloat(self: *Reader) !f32 {
        try self.advance(4);
        return number.readBig(f32, self.buffer.items[self.position - 4 .. self.position + 1]);
    }

    pub inline fn readDouble(self: *Reader) !f64 {
        try self.advance(8);
        return number.readBig(f64, self.buffer.items[self.position - 8 .. self.position + 1]);
    }

    pub inline fn readString(self: *Reader) ![]const u8 {
        const size = number.readBig(i32, self.buffer.items[self.position .. self.position + 4]);
        try self.advance(4 + size);
        return self.buffer.clone().toOwnedSlice()[self.position - 4 - size .. self.position + 1];
    }

    pub inline fn readVarInt(self: *Reader) !i32 {
        const result = try number.readVarInt(self.buffer.items[self.position..]);
        self.position += result[1];
        return result[0];
    }

    pub inline fn readVarLong(self: *Reader) !i64 {
        const result = try number.readVarLong(self.buffer.items[self.position..]);
        self.position += result[1];
        return result[0];
    }

    //pub inline fn writeEntityMetadata(self: *Reader, metadata: types.EntityMetadata) !void {
    //    try self.buffer.appendSlice(metadata.write(self.version));
    //}

    //pub inline fn writeSlot(self: *Reader, slot: types.Slot) !void {
    //    try self.buffer.appendSlice(slot.write(self.version));
    //}

    pub inline fn readTag(self: *Reader, typ: io.nbt.Type) !io.nbt.Tag {
        const tag = try io.nbt.Tag.read(self.buffer.items[self.position..], typ);
        try self.advance(tag[1]);
        return tag[0];
    }

    pub inline fn readNamedTag(self: *Reader) !io.nbt.NamedTag {
        const tag = try io.nbt.NamedTag.read(self.buffer.items[self.position..]);
        try self.advance(tag[1]);
        return tag[0];
    }

    pub inline fn readPosition(self: *Reader) !types.Vec3i {
        try self.advance(8);
        return types.Vec3i.read(self.version, self.buffer.items[self.position - 8 .. self.position]);
    }

    pub inline fn readUUID(self: *Reader) !types.UUID {
        try self.advance(16);
        return .{ .bytes = self.buffer.items[self.position - 16 .. self.position] };
    }

    pub fn readArray(self: *Reader, comptime T: type, item_type: ?ArrayItemType, size: usize) ![]T {
        const item_size = @sizeOf(T);
        var output = allocator.alloc(T, size);
        var s: usize = self.position;
        var e: usize = s;
        var i: usize = 0;

        if (T == bool or
            T == i8 or
            T == u8 or
            T == i16 or
            T == u16 or
            (T == i32 and item_type != .VarNum) or
            (T == i64 and item_type != .VarNum) or
            T == f32 or
            T == f64) self.advance(size * item_size);

        switch (T) {
            bool => while (i < size) : (i += 1) {
                output[i] = self.buffer.items[s] != 0x00;
                s += 1;
            },
            i8 => while (i < size) : (i += 1) {
                output[i] = @bitCast(self.buffer.items[s]);
                s += 1;
            },
            u8 => output = self.buffer.items[self.position - size .. self.position],
            i16 => while (i < size) : (i += 1) {
                e += 2;
                output[i] = number.readBig(i16, self.buffer.items[s..e]);
                s = e;
            },
            u16 => while (i < size) : (i += 1) {
                e += 2;
                output[i] = number.readBig(u16, self.buffer.items[s..e]);
                s = e;
            },
            i32 => if (item_type != null and item_type.? == .VarNum) {
                while (i < size) : (i += 1) {
                    const result = number.readVarInt(self.buffer.items[s .. s + 5]);
                    output[i] = result[0];
                    s += output[1];
                }
            } else {
                while (i < size) : (i += 1) {
                    e += 4;
                    output[i] = number.readBig(i32, self.buffer.items[s..e]);
                    s = e;
                }
            },
            i64 => if (item_type != null and item_type.? == .VarNum) {
                const result = number.readVarLong(self.buffer.items[s .. s + 10]);
                output[i] = result[0];
                s += output[1];
            } else {
                while (i < size) : (i += 1) {
                    e += 8;
                    output[i] = number.readBig(i64, self.buffer.items[s..e]);
                    s = e;
                }
            },
            f32 => while (i < size) : (i += 1) {
                e += 4;
                output[i] = number.readBig(f32, self.buffer.items[s..e]);
                s = e;
            },
            f64 => while (i < size) : (i += 1) {
                e += 8;
                output[i] = number.readBig(f64, self.buffer.items[s..e]);
                s = e;
            },
            else => if (@hasDecl(T, "read")) {
                const fi = @typeInfo(T.read);
                if (fi != .Fn) @compileError("bad array item type");

                if (fi.Fn.params.len == 1) {
                    if (fi.Fn.params[0].type != []const u8) @compileError("bad array item type");
                } else if (fi.Fn.params.len == 2) {
                    if (fi.Fn.params[0].type != u16) @compileError("bad array item type");
                    if (fi.Fn.params[1].type != []const u8) @compileError("bad array item type");
                } else {
                    @compileError("bad array item type");
                }

                const result_type = struct { T, usize };
                const frt = fi.Fn.return_type;
                var result: result_type = undefined;
                if (frt == null) @compileError("bad array item type");
                const frti = @typeInfo(frt);
                if (frti == .ErrorUnion) {
                    if (frti.ErrorUnion.payload != result_type) @compileError("bad array item type");
                } else {
                    if (frt != result_type) @compileError("bad array item type");
                }

                while (i < size) : (i += 1) {
                    if (frti == .ErrorUnion) {
                        result = try T.read(self.version, self.buffer.items[s..]);
                    } else {
                        result = T.read(self.version, self.buffer.items[s..]);
                    }
                    output[i] = result[0];
                    s += result[1];
                }

                self.position = s;
            } else {
                @compileError("bad array item type");
            },
        }
    }
};

test {
    allocator = std.testing.allocator;
}
