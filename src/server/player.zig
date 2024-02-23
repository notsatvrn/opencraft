const std = @import("std");
const network = @import("network");

const fmt = @import("../fmt.zig");

const clientbound = @import("../protocol/clientbound.zig");
const serverbound = @import("../protocol/serverbound.zig");

var allocator = @import("../util.zig").allocator;

pub const State = enum {
    handshaking,
    status,
    login,
    play,
};

pub const SendError = error{
    invalid_message,
};

pub const RecieveError = error{
    bad_state,
    invalid_message,
};

pub const Player = struct {
    socket: network.Socket,
    state: State = .handshaking,
    version: i32 = 0,

    const Self = @This();

    pub inline fn init(socket: network.Client) Self {
        return .{
            .socket = socket,
        };
    }

    pub inline fn send(self: *Self, message: clientbound.Message) !void {
        for (message.write()) |packet| {
            try self.socket.send(packet);
        }
    }

    // Recieve a message and attempt to use it.
    // If the message cannot be used here, it gets returned to be used elsewhere.
    pub fn recieve(self: *Self) !?serverbound.Message {
        var message = try self.socket.receive();
        if (message.len == 0) return null;

        // handle legacy server list ping
        if (message[0] == 0xFE) {
            if (message.len == 1) {
                // beta 1.8 -> 1.3
            }
            if (message[1] == 0x01) {
                if (message.len == 2) {
                    // 1.4 -> 1.5
                } else {
                    // 1.6
                }
            }
        }

        var reader = undefined;
        var length = 0;
        var id = 0;

        if (self.compressing) {
            reader = fmt.packet.Reader.init(0, message);
        } else {
            reader = fmt.packet.Reader.init(0, message);
            length = try reader.readVarInt();
            id = try reader.readVarInt();
        }

        switch (self.state) {
            .handshaking => switch (id) {
                0x00 => { // HANDSHAKING - SERVERBOUND - Handshake (0x00)
                    const version_data = try reader.readVarInt();
                    const version_size = version_data[1];

                    const host_data = try reader.readVarInt(message[version_size - 1 .. message.len]);
                    const offset = version_size + host_data[0] + host_data[1] + 1;
                    const state = try reader.readVarInt(message[offset..message.len])[0];

                    if (state[0] == 1) {
                        self.state = State.status;
                    } else if (state[0] == 2) {
                        self.state = State.login;
                    } else {
                        return RecieveError.bad_state;
                    }
                },
                else => return RecieveError.invalid_message,
            },
            .play => switch (id) {
                0x00 => try self.sendMessage(.{ .keep_alive = message }), // PLAY - SERVERBOUND - Keep Alive (0x00)
                else => return RecieveError.invalid_message,
            },
        }

        return null;
    }
};
