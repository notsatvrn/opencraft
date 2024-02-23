// CLIENTBOUND MESSAGES - server -> client
// Based on the latest stable version of the protocol: https://wiki.vg/Protocol

const std = @import("std");
const fmt = @import("../fmt.zig");

const play = @import("client/play.zig");

pub const Message = union(enum) {
    status: StatusMessage,
    login: LoginMessage,
    play: PlayMessage,

    pub fn write(self: Message) !?[][]const u8 {
        return switch (self) {
            Message.status => |v| v.write(),
            Message.login => |v| v.write(),
            Message.play => |v| v.write(),
        };
    }
};

pub const StatusMessage = union(enum) {
    pub fn write(self: StatusMessage) !?[][]const u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const LoginMessage = union(enum) {
    pub fn write(self: LoginMessage) !?[][]const u8 {
        return switch (self) {
            else => null,
        };
    }
};

pub const PlayMessage = union(enum) {
    spawn_entity: play.SpawnEntity,
    spawn_exp_orb: play.SpawnEXPOrb,
    spawn_player: play.SpawnPlayer,
    keep_alive: []u8,

    pub fn write(self: PlayMessage, writer: *fmt.packet.PacketWriter, version: u16) !?[][]const u8 {
        return switch (self) {
            PlayMessage.spawn_entity => |v| v.write(writer, version),
            PlayMessage.spawn_exp_orb => |v| v.write(writer, version),
            PlayMessage.spawn_player => |v| v.write(writer, version),
            PlayMessage.keep_alive => |_| [_]u8{},
            else => null,
        };
    }
};
