// 1.7.2-1.7.5

pub const std = @import("std");
pub const messages = @import("../packets.zig");

pub fn serializeCBPMSpawnEntity(message: messages.CBPMSpawnEntity) [][]u8 {
    _ = message;
}
