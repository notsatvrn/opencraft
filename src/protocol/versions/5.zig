// 1.7.6-1.7.10

pub const std = @import("std");
pub const messages = @import("../messages.zig");

pub fn serializeClientPlaySpawnEntity(message: messages.ClientPlaySpawnEntity) [][]u8 {
    _ = message;
}
