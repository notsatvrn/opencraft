const global = @import("../global.zig");

const network = @import("network");

const Client = @import("network.zig").Client;
const allocator = @import("util.zig").allocator;

const std = @import("std");

pub var clients = std.ArrayList(Client).init(allocator);

pub const Server = struct {
    socket: network.Socket,

    pub fn init(ip: []const u8, port: usize) !Server {
        try network.init();

        var socket = try network.Socket.create(.ipv4, .tcp);

        try socket.bind(.{
            .address = .{ .ipv4 = network.Address.IPv4.parse(ip) },
            .port = port,
        });

        return .{ .socket = socket };
    }

    pub fn listen(self: *Server) !void {
        try self.socket.listen();

        while (global.state == global.State.running) {}
    }

    pub fn deinit(self: *Server) void {
        self.socket.close();
        network.deinit();
    }
};
