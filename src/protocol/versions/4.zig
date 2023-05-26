// 1.7.2-1.7.5

pub const std = @import("std");
pub const messages = @import("../messages.zig");

pub fn serializeClientPlaySpawnEntity(message: messages.ClientPlaySpawnEntity) [][]u8 {
    _ = message;
}
