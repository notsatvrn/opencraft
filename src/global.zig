const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const State = enum {
    starting_up,
    running,
    shutting_down,
};

pub var state = State.starting_up;
