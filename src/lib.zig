pub const global = @import("global.zig");
pub const config = @import("config.zig");
pub const io = @import("io.zig");
pub const network = @import("network.zig");
pub const protocol = @import("protocol.zig");
pub const tasks = @import("tasks.zig");
pub const types = @import("types.zig");
pub const world = @import("world.zig");

test {
    _ = global;
    _ = config;
    _ = io;
    _ = network;
    _ = protocol;
    _ = tasks;
    _ = types;
    _ = world;
}
