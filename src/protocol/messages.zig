// The protocol messages.
// Messages may be written into multiple packets.

const std = @import("std");

const io = @import("../io.zig");
const types = @import("../types.zig");

// SERVER MESSAGES - client -> server

pub const ServerMessage = union(enum) {
    status: ServerStatusMessage,
    login: ServerLoginMessage,
    play: ServerPlayMessage,

    pub fn write(self: ServerMessage) ?[]u8 {
        return switch (self) {
            ServerMessage.status => |v| v.write(),
            ServerMessage.login => |v| v.write(),
            ServerMessage.play => |v| v.write(),
        };
    }
};

pub const ServerStatusMessage = union(enum) {
    pub fn write(self: ServerStatusMessage) ?[]u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const ServerLoginMessage = union(enum) {
    pub fn write(self: ServerLoginMessage) ?[]u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const ServerPlayMessage = union(enum) {
    keep_alive: []u8,

    pub fn write(self: ServerPlayMessage) ?[]u8 {
        return switch (self) {
            ServerPlayMessage.keep_alive => |v| io.bytes.appendByteSlices(.{ .{0x00}, v }),
            else => null,
        };
    }
};

// CLIENT MESSAGES - server -> client

pub const ClientMessage = union(enum) {
    status: ClientStatusMessage,
    login: ClientLoginMessage,
    play: ClientPlayMessage,

    pub fn write(self: ClientMessage) ?[]u8 {
        return switch (self) {
            ClientMessage.status => |v| v.write(),
            ClientMessage.login => |v| v.write(),
            ClientMessage.play => |v| v.write(),
        };
    }
};

pub const ClientStatusMessage = union(enum) {
    pub fn write(self: ClientStatusMessage) ?[]u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const ClientLoginMessage = union(enum) {
    pub fn write(self: ClientLoginMessage) ?[]u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const ClientPlayMessage = union(enum) {
    spawn_entity: ClientPlaySpawnEntity,
    spawn_exp_orb: ClientPlaySpawnEXPOrb,
    spawn_player: ClientPlaySpawnPlayer,
    keep_alive: []u8,

    pub fn write(self: ClientPlayMessage) ?[]u8 {
        return switch (self) {
            ClientPlayMessage.spawn_entity => |v| v.write(),
            ClientPlayMessage.spawn_exp_orb => |v| v.write(),
            ClientPlayMessage.spawn_player => |v| v.write(),
            ClientPlayMessage.keep_alive => |v| io.bytes.appendByteSlices(.{ .{0x00}, v }),
            else => null,
        };
    }
};

// CLIENT - PLAY - Spawn Entity
// >107: 0x0E
// 107+ (1.9.0+): 0x00
// 762+ (1.19.4): 0x01 (Bundle Delimiter added at 0x00)
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

// CLIENT - PLAY - Spawn Experience Orb
// >107: 0x11
// 107+ (1.9.0+): 0x01
// 762+ (1.19.4): 0x02 (Bundle Delimiter added at 0x00)
pub const ClientPlaySpawnEXPOrb = struct {
    id: i32,
    pos: types.Vec3d, // Serialized as fixed-point numbers on 47 (1.8.x).
    count: i16,
};

// CLIENT - PLAY - Spawn Player
// <107 (<1.9.0): idk im too lazy to check rn
// 107-762 (1.9.0-1.19.4): whatever
// >762 (>1.19.4): 0x03 (Bundle Delimiter added at 0x00)
pub const ClientPlaySpawnPlayer = struct {
    id: i32,
    uuid: types.UUID,
    pos: types.Vec3d,
    pitch: u8,
    yaw: u8,
    meta: types.EntityMeta,
};

// CLIENT - PLAY - Animation (0x06)
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

// CLIENT - PLAY - Statistics (0x07)
pub const ClientPlayStatistics = struct {
    id: i32,
    animation: u8,
};
