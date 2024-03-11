const std = @import("std");

const fs = @import("../fs.zig");
const world = @import("../world.zig");

var allocator = @import("../util.zig").allocator;

pub const NetworkConfig = struct {
    enabled: bool = true,
    host: []const u8 = "0.0.0.0",
    port: u16 = 25565,
    online: bool = true,
    compression_threshold: ?u16 = 256,
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
    enabled: bool = false,
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
    protection: bool = false,
    operator_role: []const u8 = "owner",
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

pub fn loadPath(path: []const u8) !Config {
    var config: Config = undefined;
    if (!fs.exists(path)) {
        var string = std.ArrayList(u8).init(allocator);
        defer string.deinit();

        config = Config{};
        try std.json.stringify(config, .{
            .whitespace = .indent_tab,
        }, string.writer());

        (try fs.File.newWithContents(path, try string.toOwnedSlice())).close();
    } else {
        var file = try fs.File.open(path);
        config = (try std.json.parseFromSlice(Config, allocator, try file.read(), .{})).value;
        file.close();
    }
    return config;
}
