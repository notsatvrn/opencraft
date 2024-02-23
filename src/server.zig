const std = @import("std");
const network = @import("network");

const config = @import("server/config.zig");
const player = @import("server/player.zig");

pub const Server = struct {
    lock: std.Thread.RwLock = .{},
    config: config.Config,
    state: State = .starting_up,

    pub const State = enum {
        starting_up,
        running,
        shutting_down,
    };
};

pub fn main() !void {
    std.log.info("welcome to opencraft!", .{});

    const cfg = try config.loadPath("config.json");
    std.log.info("config loaded", .{});

    _ = Server{
        .config = cfg,
    };

    if (cfg.network.enabled) {
        //std.Thread.spawn(.{}, function: anytype, .{})
        var socket = try network.Socket.create(.ipv4, .tcp);
        socket.bindToPort(cfg.network.port);
        socket.listen();

        while (true) {
            var client = try socket.accept();
            defer client.close();

            std.debug.print("Client connected from {}.\n", .{
                try client.getLocalEndPoint(),
            });

            std.debug.print("Client disconnected.\n", .{});
        }
    }
}
