// The protocol messages.
// Messages may be written into multiple packets.

const std = @import("std");

const io = @import("../io.zig");
const types = @import("../types.zig");

// SERVERBOUND MESSAGES - client -> server

pub const ServerMessage = union(enum) {
    status: ServerStatusMessage,
    login: ServerLoginMessage,
    play: ServerPlayMessage,

    const Self = @This();

    pub fn write(self: *Self) []u8 {
        return switch (self) {
            Self.status => |v| v.write(),
            Self.login => |v| v.write(),
            Self.play => |v| v.write(),
        };
    }
};

pub const ServerStatusMessage = union(enum) {};

pub const ServerLoginMessage = union(enum) {};

pub const ServerPlayMessage = union(enum) {
    keep_alive: []u8,

    const Self = @This();

    pub fn write(self: *Self) ?[]u8 {
        return switch (self) {
            Self.keep_alive => |v| io.bytes.appendByteSlices(.{ .{0x00}, v }),
            else => null,
        };
    }
};

// CLIENTBOUND MESSAGES - server -> client

pub const ClientMessage = union(enum) {
    status: ClientStatusMessage,
    login: ClientLoginMessage,
    play: ClientPlayMessage,

    const Self = @This();

    pub fn write(self: *Self) []u8 {
        return switch (self) {
            Self.status => |v| v.write(),
            Self.login => |v| v.write(),
            Self.play => |v| v.write(),
        };
    }
};

pub const ClientStatusMessage = union(enum) {};

pub const ClientLoginMessage = union(enum) {};

pub const ClientPlayMessage = union(enum) {
    spawn_entity: ClientPlaySpawnEntity,
    spawn_exp_orb: ClientPlaySpawnEXPOrb,
    spawn_player: ClientPlaySpawnPlayer,
    keep_alive: []u8,

    const Self = @This();

    pub fn write(self: *Self) ?[]u8 {
        return switch (self) {
            Self.keep_alive => |v| io.bytes.appendByteSlices(.{ .{0x00}, v }),
            Self.spawn_object => |v| v.write(),
            else => null,
        };
    }
};

// CLIENTBOUND - PLAY - Spawn Entity
// >107: 0x0E
// 107+ (1.9.0+): 0x00
// NOTE: The Spawn (Global/Weather) Entity packet was merged into this packet in 735 (1.16).
// NOTE: The Spawn (Mob/Living Entity) packet was merged into this packet in 1.19 (759).
// NOTE: The Spawn Painting packet was merged into this packet in 1.19 (759).
pub const ClientPlaySpawnEntity = struct {
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
};

// CLIENTBOUND - PLAY - Spawn Experience Orb
// >107: 0x11
// 107+ (1.9.0+): 0x01
pub const ClientPlaySpawnEXPOrb = struct {
    id: i32,
    pos: types.Vec3d, // Serialized as fixed-point numbers on 47 (1.8.x).
    count: i16,
};

// CLIENTBOUND - PLAY - Spawn Player (0x05)
pub const ClientPlaySpawnPlayer = struct {
    id: i32,
    uuid: types.UUID,
    pos: types.Vec3d,
    pitch: u8,
    yaw: u8,
    meta: types.EntityMeta,
};

// CLIENTBOUND - PLAY - Animation (0x06)
pub const ClientPlayAnimation = struct {
    id: i32,
    animation: Animation,

    pub fn write(self: ClientPlayAnimation) []u8 {
        io.packet.writer.writeVarInt(self.id);
        io.packet.writer.writeUnsignedByte(@as(u8, @enumToInt(self.animation)));
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

// CLIENTBOUND - PLAY - Statistics (0x07)
pub const ClientPlayStatistics = struct {
    id: i32,
    animation: u8,
};
