// 1.8.x

pub const std = @import("std");
pub const messages = @import("../messages.zig");

pub fn serializeClientPlaySpawnEntity(message: messages.ClientPlaySpawnEntity) [][]u8 {
    _ = message;
}
