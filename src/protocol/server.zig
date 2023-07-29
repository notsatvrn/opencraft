// SERVER MESSAGES - client -> server
// Based on the latest stable version of the protocol: https://wiki.vg/Protocol

const std = @import("std");
const io = @import("../io.zig");

pub const Message = union(enum) {
    status: StatusMessage,
    login: LoginMessage,
    play: PlayMessage,

    pub fn write(self: Message, writer: *io.packet.PacketWriter, version: u16) !?[][]const u8 {
        return switch (self) {
            Message.status => |v| v.write(writer, version),
            Message.login => |v| v.write(writer, version),
            Message.play => |v| v.write(writer, version),
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
    keep_alive: []u8,

    pub fn write(self: PlayMessage) !?[][]const u8 {
        return switch (self) {
            PlayMessage.keep_alive => |_| [_]u8{},
            else => null,
        };
    }
};
