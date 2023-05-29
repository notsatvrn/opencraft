pub const bytes = @import("io/bytes.zig");
pub const fs = @import("io/fs.zig");
//pub const mutf8 = @import("io/mutf8.zig"); // TODO: modified UTF-8
pub const nbt = @import("io/nbt.zig");
pub const number = @import("io/number.zig");
pub const packet = @import("io/packet.zig");

test {
    _ = bytes;
    _ = fs;
    //_ = mutf8; // TODO: modified UTF-8
    _ = nbt;
    _ = number;
    _ = packet;
}
