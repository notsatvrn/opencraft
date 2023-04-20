// This file is part of a port of Alternate Current's redstone engine.
// Alternate Current was created by Space Walker (@SpaceWalkerRS), and is licensed under the MIT license.
// The original code can be found here: https://github.com/SpaceWalkerRS/alternate-current.

const math = @import("../util/math.zig");

const Direction = math.Direction;

pub const WireHandler = struct {
    pub const Directions = struct {
        pub const ALL = []Direction{ Direction.west, Direction.north, Direction.east, Direction.south, Direction.down, Direction.up };
        pub const HORIZONTAL = []Direction{ Direction.west, Direction.north, Direction.east, Direction.south };

        pub const WEST: i32 = 0b000; // 0
        pub const NORTH: i32 = 0b001; // 1
        pub const EAST: i32 = 0b010; // 2
        pub const SOUTH: i32 = 0b011; // 3
        pub const DOWN: i32 = 0b100; // 4
        pub const UP: i32 = 0b101; // 5

        pub fn iOpposite(iDir: i32) i32 {
            return iDir ^ (0b10 >> (iDir >> 2));
        }

        pub const I_EXCEPT = [_][5]?i32{
            .{ null, NORTH, EAST, SOUTH, DOWN, UP },
            .{ WEST, null, EAST, SOUTH, DOWN, UP },
            .{ WEST, NORTH, null, SOUTH, DOWN, UP },
            .{ WEST, NORTH, EAST, null, DOWN, UP },
            .{ WEST, NORTH, EAST, SOUTH, null, UP },
            .{ WEST, NORTH, EAST, SOUTH, DOWN, null },
        };

        pub const I_EXCEPT_CARDINAL = [_][4]?i32{
            .{ null, NORTH, EAST, SOUTH },
            .{ WEST, null, EAST, SOUTH },
            .{ WEST, NORTH, null, SOUTH },
            .{ WEST, NORTH, EAST, null },
            .{ WEST, NORTH, EAST, SOUTH },
            .{ WEST, NORTH, EAST, SOUTH },
        };
    };

    pub const FLOW_IN_FLOW_OUT = []i32{
        -1, // 0b0000: - -> x
        Directions.WEST, // 0b0001: west -> west
        Directions.NORTH, // 0b0010: north -> north
        Directions.NORTH, // 0b0011: west/north -> north
        Directions.EAST, // 0b0100: east -> east
        -1, // 0b0101: west/east -> x
        Directions.EAST, // 0b0110: north/east -> east
        Directions.NORTH, // 0b0111: west/north/east -> north
        Directions.SOUTH, // 0b1000: south -> south
        Directions.WEST, // 0b1001: west/south -> west
        -1, // 0b1010: north/south -> x
        Directions.WEST, // 0b1011: west/north/south -> west
        Directions.SOUTH, // 0b1100: east/south -> south
        Directions.SOUTH, // 0b1101: west/east/south -> south
        Directions.EAST, // 0b1110: north/east/south -> east
        -1, // 0b1111: west/north/east/south -> x
    };

    pub const FULL_UPDATE_ORDERS = []i32{
        .{ Directions.WEST, Directions.EAST, Directions.NORTH, Directions.SOUTH, Directions.DOWN, Directions.UP },
        .{ Directions.NORTH, Directions.SOUTH, Directions.EAST, Directions.WEST, Directions.DOWN, Directions.UP },
        .{ Directions.EAST, Directions.WEST, Directions.SOUTH, Directions.NORTH, Directions.DOWN, Directions.UP },
        .{ Directions.SOUTH, Directions.NORTH, Directions.WEST, Directions.EAST, Directions.DOWN, Directions.UP },
    };
};
