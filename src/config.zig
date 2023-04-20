const std = @import("std");

const io = @import("io.zig");
const world = @import("world.zig");

const allocator = @import("global.zig").allocator;

pub var config: ?Config = null;

pub const NetworkConfig = struct {
    enabled: bool = true,
    host: []const u8 = "0.0.0.0",
    port: u16 = 25565,
    online: bool = true,
    compression_threshold: i32 = 256,
    white_list: bool = false,
};

pub const StatusConfig = struct {
    enabled: bool = true,
    message: []const u8 = "A Minecraft Server",
};

pub const QueryConfig = struct {
    enabled: bool = true,
    host: []const u8 = "0.0.0.0",
    port: u16 = 25565,
};

pub const ResourcePackConfig = struct {
    enabled: bool = true,
    url: []const u8 = "",
    hash: []const u8 = "",
    required: bool = false,
    prompt: []const u8 = "",
};

pub const WorldConfig = struct {
    seed: []const u8 = "",
    name: []const u8 = "world",
    difficulty: []const u8 = "normal",
    hardcore: bool = false,
    op_permission_level: u3 = 4,
};

pub const AnimalsConfig = struct {
    enabled: bool = true,
    limit: i32 = 16,
    delay: i32 = 400,
    activate: i32 = 32,
    track: i32 = 48,
};

pub const MonstersConfig = struct {
    enabled: bool = true,
    limit: i32 = 72,
    delay: i32 = 4,
    activate: i32 = 32,
    track: i32 = 48,
};

pub const AmbientsConfig = struct {
    enabled: bool = true,
    limit: i32 = 16,
    delay: i32 = 400,
    activate: i32 = 16,
    track: i32 = 24,
};

pub const DimensionConfig = struct {
    enabled: bool = true,

    structures: bool = true,
    npcs: bool = true,

    animals: AnimalsConfig = .{},
    monsters: MonstersConfig = .{},
    ambients: AmbientsConfig = .{},

    view_distance: u32 = 8,
};

pub const Config = struct {
    network: NetworkConfig = .{},
    status: StatusConfig = .{},
    query: QueryConfig = .{},
    resource_pack: ResourcePackConfig = .{},

    world: WorldConfig = .{},

    dimensions: struct {
        default: DimensionConfig = .{},
        overworld: ?DimensionConfig = null,
        nether: ?DimensionConfig = null,
        end: ?DimensionConfig = null,
    } = .{},
};

pub const ConfigError = error{
    bad_compression_threshold,
};

pub fn load() !void {
    if (config != null) return;

    config = Config{};

    if (!io.fs.File.exists("config.json")) {
        var string = std.ArrayList(u8).init(allocator);
        defer string.deinit();

        try std.json.stringify(config.?, .{ .whitespace = .{} }, string.writer());

        (try io.fs.File.createWithContents("config.json", try string.toOwnedSlice())).close();
    } else {
        var file = try io.fs.File.open("config.json");
        defer file.close();

        var stream = std.json.TokenStream.init(try file.read());
        config = try std.json.parse(Config, &stream, .{ .allocator = allocator });

        if (config.?.network.compression_threshold < -1) {
            return ConfigError.bad_compression_threshold;
        }
    }
}
