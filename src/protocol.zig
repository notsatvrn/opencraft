const std = @import("std");

const io = @import("io.zig");
const network = @import("network.zig");

const client = @import("protocol/client.zig");
const server = @import("protocol/server.zig");

const PacketWriter = io.packet.Writer;
const PacketReader = io.packet.Reader;

// MESSAGE HANDLER / PARSER

pub const SendMessageError = error{
    invalid_message,
};

pub const RecieveMessageError = error{
    bad_state,
    invalid_message,
};

pub const State = enum {
    handshaking,
    status,
    login,
    play,
};

pub const MessageHandler = struct {
    socket: network.Client,
    state: State = State.handshaking,
    compressing: bool = false,
    version: i32 = 0,
    writer: PacketWriter = PacketWriter.init(0),
    reader: PacketReader = PacketReader.init(0, ""),
    messages: usize = 0,

    pub inline fn init(socket: network.Client) MessageHandler {
        return .{
            .socket = socket,
        };
    }

    pub inline fn sendMessage(self: *MessageHandler, message: client.Message) !void {
        for (message.write()) |packet| {
            try self.socket.send(packet);
        }
    }

    // Recieve a message and attempt to use it.
    // If the message cannot be used here, it gets returned to be used elsewhere.
    pub fn recieveMessage(self: *MessageHandler) !?client.Message {
        var message = try self.socket.receive();
        if (message.len == 0) return null;

        var id = 0;

        if (message[0] == 0xFE) { // legacy server list ping
            id = 0xFE;
        } else if (self.compressing) {} else {
            var length_data = try self.reader.readVarInt(message);
            message = message[length_data[0]..message.len];
            var id_data = try self.reader.readVarInt(message);
            id = id_data[0];
            message = message[id_data[0]..message.len];
        }

        if (self.state == State.handshaking) switch (id) {
            0x00 => { // HANDSHAKING - SERVERBOUND - Handshake (0x00)
                var version_data = try self.reader.readVarInt(message);
                var version_size = version_data[1];

                var host_data = try self.reader.readVarInt(message[version_size - 1 .. message.len]);
                var offset = version_size + host_data[0] + host_data[1] + 1;
                var state = try self.reader.readVarInt(message[offset..message.len])[0];

                if (state[0] == 1) {
                    self.state = State.status;
                } else if (state[0] == 2) {
                    self.state = State.login;
                } else {
                    return RecieveMessageError.bad_state;
                }
            },
            0xFE => if (message[1] == 0x01) { // 1.4-1.6

            } else { // beta 1.8 -> 1.3

            },
            else => return RecieveMessageError.invalid_message,
        } else if (self.state == State.play) switch (id) {
            0x00 => try self.sendMessage(.{ .keep_alive = message }), // PLAY - SERVERBOUND - Keep Alive (0x00)
            else => return RecieveMessageError.invalid_message,
        };

        return null;
    }
};

test {
    _ = client;
    _ = server;
}
