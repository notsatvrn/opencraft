const std = @import("std");

pub const Chat = struct {
    pub fn write(self: Chat, version: u16) ![]const u8 {
        _ = version;
        _ = self;
    }
};
