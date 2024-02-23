pub const Axis = enum { x, y, z };

pub const DirectionFull = enum {
    south,
    south_southwest,
    southwest,
    west_southwest,
    west,
    west_northwest,
    northwest,
    north_northwest,
    north,
    north_northeast,
    northeast,
    east_northeast,
    east,
    east_southeast,
    southeast,
    south_southeast,
};

pub const Direction = enum {
    north,
    east,
    south,
    west,
    down,
    up,
};

pub const DirectionXZ = enum {
    north,
    east,
    south,
    west,

    const Self = @This();

    pub inline fn toDirection(self: Self) Direction {
        return switch (self) {
            Self.north => Direction.north,
            Self.east => Direction.east,
            Self.south => Direction.south,
            Self.west => Direction.west,
        };
    }
};
