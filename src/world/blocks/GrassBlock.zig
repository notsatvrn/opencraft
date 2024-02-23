const Version = @import("../../util.zig").Version;
const world = @import("../../world.zig");

// STRUCT

const Self = @This();

// METHODS

pub inline fn getLegacyID() world.LegacyID {
    return comptime .{ .value = 2, .variant = 0 };
}

pub inline fn getStringID(version: Version) world.StringID {
    return .{ .name = if (version < .v1_13) "grass" else "grass_block" };
}

pub inline fn getStackSize() usize {
    return 64;
}
