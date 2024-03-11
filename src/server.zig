const std = @import("std");
const network = @import("network");

const config = @import("server/config.zig");
const player = @import("server/player.zig");

pub const Server = struct {
    lock: std.Thread.RwLock = .{},
    config: config.Config,
    state: State = .starting_up,

    const Self = @This();

    pub const State = enum {
        starting_up,
        running,
        shutting_down,
    };

    pub fn listen(self: *Self) !void {
        var socket = try network.Socket.create(.ipv4, .tcp);
        try socket.bindToPort(self.config.network.port);
        try socket.listen();

        while (true) {
            var client = try socket.accept();
            defer client.close();

            std.log.info("Client connected from {}.\n", .{
                try client.getLocalEndPoint(),
            });

            std.log.info("Client disconnected.\n", .{});
        }
    }
};

pub fn main() !void {
    std.log.info("welcome to opencraft!", .{});

    const cfg = try config.loadPath("config.json");
    std.log.info("config loaded", .{});

    var server = Server{
        .config = cfg,
    };

    if (cfg.network.enabled) {
        var thread = try std.Thread.spawn(.{}, Server.listen, .{&server});
        thread.detach();
    }

    std.log.info("now listening", .{});
}
