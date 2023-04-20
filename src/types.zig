const std = @import("std");

const chat = @import("types/chat.zig");
const entity = @import("types/entity.zig");
const math = @import("types/math.zig");
const uuid = @import("types/uuid.zig");

pub usingnamespace @import("types/chat.zig");
pub usingnamespace @import("types/entity.zig");
pub usingnamespace @import("types/math.zig");
pub usingnamespace @import("types/uuid.zig");

test {
    _ = chat;
    _ = entity;
    _ = math;
    _ = uuid;
}
