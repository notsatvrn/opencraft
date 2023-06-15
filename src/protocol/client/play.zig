// Based on the latest stable version of the protocol: https://wiki.vg/Protocol

const std = @import("std");
const io = @import("../../io.zig");
const types = @import("../../types.zig");

// Spawn Entity
// <107: 0x0E
// 107-761: 0x00
// >=762: 0x01
// NOTE: The Spawn (Global/Weather) Entity packet was merged into this packet in 735.
// NOTE: The Spawn (Mob/Living Entity) packet was merged into this packet in 759.
// NOTE: The Spawn Painting packet was merged into this packet in 759.
pub const ClientPlaySpawnEntity = packed struct {
    id: i32,
    uuid: types.UUID,
    typ: i32, // i8/Byte: <404 (1.13.2), i32/VarInt: >=477 (1.14)
    pos: types.Vec3d,
    pitch: u8,
    yaw: u8,
    head_pitch: u8, // may not be sent
    head_yaw: u8, // may not be sent
    data: i32,
    velocity: types.Vec3s, // not sent on 47 (1.8.x) if data == 0
    meta: ?types.EntityMeta,

    pub fn write(self: ClientPlaySpawnEntity, writer: *io.packet.PacketWriter, version: u16) ![]const u8 {
        _ = self;
        if (version < 107) {
            try writer.writeUnsignedByte(0x0E);
        } else if (version < 762) {
            try writer.writeUnsignedByte(0x00);
        } else { // >= 762
            try writer.writeUnsignedByte(0x01);
        }
        return writer.finish();
    }
};

// Spawn Experience Orb
// <107: 0x11
// 107-761: 0x01
// >=762: 0x02
pub const ClientPlaySpawnEXPOrb = packed struct {
    id: i32,
    pos: types.Vec3d, // fixed-point number: <=47
    count: i16,

    pub fn write(self: ClientPlaySpawnEXPOrb, writer: *io.packet.PacketWriter, version: u16) ![]const u8 {
        _ = self;
        if (version < 107) {
            try writer.writeUnsignedByte(0x11);
        } else if (version < 762) {
            try writer.writeUnsignedByte(0x01);
        } else { // >= 762
            try writer.writeUnsignedByte(0x04);
        }
        return writer.finish();
    }
};

// Spawn Player
// <107: 0x06
// 107-761: 0x05
// >=762: 0x03
pub const ClientPlaySpawnPlayer = packed struct {
    id: i32,
    uuid: types.UUID,
    pos: types.Vec3d,
    pitch: u8,
    yaw: u8,
    meta: types.EntityMeta,

    pub fn write(self: ClientPlaySpawnPlayer, writer: *io.packet.PacketWriter, version: u16) ![]const u8 {
        _ = self;
        if (version < 107) {
            try writer.writeUnsignedByte(0x06);
        } else if (version < 762) {
            try writer.writeUnsignedByte(0x05);
        } else { // >= 762
            try writer.writeUnsignedByte(0x03);
        }
        return writer.finish();
    }
};

// Animation
// <50: 0x0B
// >=762: 0x04
pub const ClientPlayAnimation = packed struct {
    id: i32,
    animation: Animation,

    pub fn write(self: ClientPlayAnimation, writer: *io.packet.PacketWriter, version: u16) ![]const u8 {
        if (version < 50) {
            try writer.writeUnsignedByte(0x0B);
        } else { // >= 762
            try writer.writeUnsignedByte(0x04);
        }

        try writer.writeVarInt(self.id);
        try writer.writeUnsignedByte(@as(u8, @enumToInt(self.animation)));
        return writer.finish();
    }
};

pub const Animation = enum {
    swing,
    damage,
    leave_bed,
    swing_offhand,
    critical,
    magic_critical,
};
