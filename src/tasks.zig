const std = @import("std");

const Allocator = std.mem.Allocator;
const sleep = std.time.sleep;
const ns_per_s = std.time.ns_per_s;
const Timer = std.time.Timer;

pub const Task = union(enum) {
    function: fn (*TaskExecutor) anyerror!void,
};

pub const TaskExecutor = struct {
    allocator: Allocator,

    initial: std.ArrayList(Task),
    pending: std.ArrayList(Task),
    final: std.ArrayList(Task),

    nspt: u64,
    tick: u128,

    const Self = @This();

    pub inline fn init(allocator: Allocator, tps: usize) Self {
        return .{
            .allocator = allocator,
            .initial = std.ArrayList(Task).init(allocator),
            .pending = std.ArrayList(Task).init(allocator),
            .final = std.ArrayList(Task).init(allocator),
            .nspt = (ns_per_s / @as(u64, tps)),
        };
    }

    pub inline fn addInitialTask(self: *Self, task: Task) !void {
        try self.initial.append(task);
    }

    pub inline fn addTask(self: *Self, task: Task) !void {
        try self.pending.append(task);
    }

    pub inline fn addFinalTask(self: *Self, task: Task) !void {
        try self.final.append(task);
    }

    pub inline fn setTPS(self: *Self, tps: usize) void {
        self.nspt = (ns_per_s / @as(u64, tps));
    }

    pub fn tick(self: *Self) !void {
        var timer = Timer.start();

        var delta = @as(i128, self.nspt) - @as(i128, timer.read());

        if (delta > 0) {
            sleep(@intCast(delta));
        } else {}

        self.tick += 1;
    }
};
