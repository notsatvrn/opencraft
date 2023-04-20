const std = @import("std");

const lib = @import("lib.zig");

pub fn main() !void {
    std.debug.print("opencraft starting...\n", .{});
    try lib.config.load();
}
