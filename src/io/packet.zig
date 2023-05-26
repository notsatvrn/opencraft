const std = @import("std");

const types = @import("../types.zig");
const number = @import("number.zig");

const allocator = @import("../global.zig").allocator;

var writer = PacketWriter.init();

pub const ArrayItemType = enum {
    VarNum,
};

pub const PacketWriter = struct {
    buffer: std.ArrayList(u8),

    pub fn init() !PacketWriter {
        return .{
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *PacketWriter) void {
        self.buffer.deinit();
    }

    pub fn finish(self: *PacketWriter) ![]const u8 {
        return self.buffer.toOwnedSlice();
    }

    pub fn writeBoolean(self: *PacketWriter, b: bool) !void {
        return if (b) self.buffer.append(0x01) else self.buffer.append(0x00);
    }

    pub fn writeByte(self: *PacketWriter, b: i8) !void {
        try self.buffer.append(@as(u8, b));
    }

    pub fn writeUnsignedByte(self: *PacketWriter, ub: u8) !void {
        try self.buffer.append(ub);
    }

    pub fn writeShort(self: *PacketWriter, s: i16) !void {
        try self.buffer.appendSlice(try number.writeBig(i16, s));
    }

    pub fn writeUnsignedShort(self: *PacketWriter, us: u16) !void {
        try self.buffer.appendSlice(try number.writeBig(u16, us));
    }

    pub fn writeInt(self: *PacketWriter, i: i32) !void {
        try self.buffer.appendSlice(try number.writeBig(i32, i));
    }

    pub fn writeLong(self: *PacketWriter, l: i64) !void {
        try self.buffer.appendSlice(try number.writeBig(i64, l));
    }

    pub fn writeFloat(self: *PacketWriter, f: f32) !void {
        try self.buffer.appendSlice(try number.writeBig(f32, f));
    }

    pub fn writeDouble(self: *PacketWriter, d: f64) !void {
        try self.buffer.appendSlice(try number.writeBig(f64, d));
    }

    pub fn writeString(self: *PacketWriter, string: []const u8) !void {
        try self.buffer.appendSlice(try number.writeBigVarInt(@as(i32, string.len)));
        try self.buffer.appendSlice(string);
    }

    pub fn writeVarInt(self: *PacketWriter, i: i32) !void {
        try self.buffer.appendSlice(number.writeBigVarInt(i));
    }

    pub fn writeVarLong(self: *PacketWriter, l: i64) !void {
        try self.buffer.appendSlice(number.writeBigVarLong(l));
    }

    pub fn writeEntityMetadata(self: *PacketWriter, metadata: types.EntityMetadata) !void {
        try self.buffer.appendSlice(metadata.write(self.version));
    }

    pub fn writeSlot(self: *PacketWriter, slot: types.Slot) !void {
        try self.buffer.appendSlice(slot.write(self.version));
    }

    pub fn writeNBT(self: *PacketWriter, nbt: types.NBTTag) !void {
        try self.buffer.appendSlice(nbt.write(self.version));
    }

    pub fn writePosition(self: *PacketWriter, pos: types.Vec3i) !void {
        try self.buffer.appendSlice(pos.write(self.version));
    }

    pub fn writeUUID(self: *PacketWriter, uuid: types.UUID) !void {
        try self.buffer.appendSlice(uuid.write(self.version));
    }

    pub fn writeArray(self: *PacketWriter, comptime T: type, item_type: ?ArrayItemType, array: []T) !void {
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
