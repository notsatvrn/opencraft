const std = @import("std");
const network = @import("network");

pub const Client = union(enum) {
    // TODO: add websocket client support.
    //websocket: WebSocketClient,
    tcp: TCPClient,

    pub fn send(self: *Client, data: []u8) !void {
        try self.tcp.send(data);
    }

    pub fn receive(self: *Client) ![]u8 {
        return try self.tcp.receive();
    }
};

const TCPClient = struct {
    socket: network.Socket,

    pub fn send(self: *TCPClient, data: []u8) !void {
        try self.socket.send(data);
    }

    pub fn receive(self: *TCPClient) ![]u8 {
        var buf: [2097151]u8 = undefined;
        var len = try self.socket.receive(&buf);
        return buf[0..len];
    }
};
