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
};

pub const DirectionWithY = enum {
    north,
    east,
    south,
    west,
    down,
    up,
};
