const types = @import("../types.zig");

// COMMON

pub const Axis = packed struct {
    axis: types.Axis = .y,
};

pub const DirectionWaterlogged = packed struct {
    facing: types.Direction = .north,
    waterlogged: bool = false,
};

// AMETHYST BUDS/CLUSTER

pub const AmethystBudsCluster = packed struct {
    facing: types.DirectionWithY = .up,
    waterlogged: bool = false,
};

// ANVIL

pub const Anvil = packed struct {
    facing: types.Direction = .north,
};

// BAMBOO

pub const Leaves = enum {
    none,
    small,
    large,
};

pub const Bamboo = packed struct {
    age: u1,
    leaves: Leaves,
    stage: u1,
};

// BANNER

pub const BannerFloor = packed struct {
    rotation: types.DirectionFull = .south,
};

pub const BannerWall = packed struct {
    facing: types.Direction = .north,
};

// BARREL

pub const Barrel = packed struct {
    facing: types.DirectionWithY = .north,
    open: bool = false,
};

// (POLISHED) BASALT

pub const Basalt = Axis;

// BED

pub const BedPart = enum {
    foot,
    head,
};

pub const Bed = packed struct {
    facing: types.Direction = .north,
    occupied: bool = false,
    part: BedPart = .foot,
};

// BEEHIVE

pub const Beehive = packed struct {
    facing: types.Direction = .north,
    honey_level: u3,
};

// BEETROOT

pub const Beetroot = packed struct {
    age: u2,
};

// BELL

pub const BellAttachment = enum {
    ceiling,
    double_wall,
    floor,
    single_wall,
};

pub const Bell = packed struct {
    attachment: BellAttachment = .floor,
    facing: types.Direction = .north,
    powered: bool = false,
};

// BIG DRIPLEAF

pub const BigDripleafTilt = enum {
    full,
    none,
    partial,
    unstable,
};

pub const BigDripleafLeaf = packed struct {
    facing: types.Direction = .north,
    tilt: BigDripleafTilt = .none,
    waterlogged: bool = false,
};

pub const BigDripleafStem = DirectionWaterlogged;

// BLAST FURNACE

pub const BlastFurnace = packed struct {
    facing: types.Direction = .north,
    lit: bool = false,
};

// BLOCK OF (STRIPPED) BAMBOO

pub const BlockOfBamboo = Axis;

// BONE BLOCK

pub const BoneBlock = Axis;

// BREWING STAND

pub const BrewingStand = packed struct {
    has_bottle_0: bool = false,
    has_bottle_1: bool = false,
    has_bottle_2: bool = false,
};

// BUBBLE COLUMN

pub const BubbleColumn = packed struct {
    drag: bool = true,
};

// BUTTON

pub const ButtonFace = enum {
    ceiling,
    floor,
    wall,
};

pub const Button = packed struct {
    face: ButtonFace = .wall,
    facing: types.Direction = .north,
    powered: bool = false,
};

// CACTUS

pub const Cactus = packed struct {
    age: u4,
};

// (CANDLE) CAKE

pub const Cake = packed struct {
    bites: u3,
};

pub const CandleCake = packed struct {
    bites: u3,
    lit: bool = false,
};

// CAMPFIRE

// CANDLE

// CARPET

// CARROT

// CAULDRON

// CAVE VINES

// CHAIN

// CHEMISTRY TABLE

// (TRAPPED) CHEST

// (ENDER) CHEST

// SIGN

pub const SignStanding = packed struct {
    direction: types.DirectionFull = .south,
    waterlogged: bool = false,
};

pub const SignWall = DirectionWaterlogged;

pub const SignHanging = packed struct {
    attached: bool = false,
    direction: types.DirectionFull = .south,
    waterlogged: bool = false,
};

pub const Sign = union(enum) {
    standing: SignStanding,
    wall: struct { bool, SignWall },
    hanging: SignHanging,
};
