// SERVERBOUND MESSAGES - client -> server
// Based on the latest stable version of the protocol: https://wiki.vg/Protocol

const std = @import("std");
const fmt = @import("../fmt.zig");

pub const Handshake = struct {
    version: i32 = 0,
    address: []const u8 = "",
    port: u16 = 0,
    login: bool,

    pub fn write(self: Message, writer: *fmt.packet.Writer, _: u16) !?[][]const u8 {
        try writer.writeVarInt(self.version);
        try writer.writeString(self.address);
        try writer.writeUnsignedShort(self.port);
        try writer.writeVarInt(if (self.login) 2 else 1);
        return .{writer.finish()};
    }
};

pub const Message = union(enum) {
    handshake: Handshake,
    status: StatusMessage,
    login: LoginMessage,
    play: PlayMessage,

    pub fn write(self: Message, writer: *fmt.packet.Writer, version: u16) !?[][]const u8 {
        return switch (self) {
            Message.handshake => |v| v.write(writer, version),
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
