const std = @import("std");

pub const Chat = struct {
    pub fn write(self: Chat, _: i32) ![]const u8 {
        _ = self;
    }
};
