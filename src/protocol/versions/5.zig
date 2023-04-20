// 1.7.6-1.7.10

pub const std = @import("std");
pub const messages = @import("../packets.zig");

pub fn serializeCBPMSpawnEntity(message: messages.CBPMSpawnEntity) [][]u8 {
    _ = message;
}
