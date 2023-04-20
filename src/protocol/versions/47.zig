// 1.8.x

pub const std = @import("std");
pub const messages = @import("../packets.zig");

pub fn serializeCBPMSpawnEntity(message: messages.CBPMSpawnEntity) [][]u8 {
    _ = message;
}
