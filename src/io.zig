pub const bytes = @import("io/bytes.zig");
pub const fs = @import("io/fs.zig");
pub const nbt = @import("io/nbt.zig");
pub const number = @import("io/number.zig");
pub const packet = @import("io/packet.zig");

test {
    _ = bytes;
    _ = fs;
    _ = nbt;
    _ = number;
    _ = packet;
}
