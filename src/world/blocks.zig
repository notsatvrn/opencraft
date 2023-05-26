// not me just implementing random stuff with zero consideration for how it actually works /s
// we're havin funnnn

const world = @import("../world.zig");
const math = @import("../types/math.zig");

pub const Block = struct {
    id: world.ID = world.ID.fromBytes("air"),
    numerical_id: ?world.NumericalID = null,
    minimum_version: ?u16 = null,
};

pub const BlockState = struct {
    block: Block = .{},
    pos: math.Vec3i = .{},
    direction: math.Direction = .north,
    inner: ?BlockStateInner = null,
};

pub const BlockStateInner = union(enum) {
    sign: SignState,
};

pub const SignState = struct {
    text: []const u8 = "",
    on_wall: bool = false,
};

