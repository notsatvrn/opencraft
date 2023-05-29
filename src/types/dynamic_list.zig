const std = @import("std");

var allocator = @import("../global.zig").allocator;

pub const DynamicListError = error{
    InvalidType,
};

// Semi-complete wrapper around std.ArrayList with dynamic union/enum type checking.
// Allows one to have an ArrayList with a union value and only one possible field for all items.
// Due to https://github.com/ziglang/zig/issues/13760, we cannot pull the enum type from the union.
// This is a terrible solution, but the only other solution I can think of is far worse.
pub fn DynamicList(comptime T: type, comptime Enum: type) type {
    return struct {
        inner: std.ArrayList(T),
        typ: Enum,

        const Self = @This();

        pub inline fn init(typ: Enum) Self {
            return .{
                .inner = std.ArrayList(T).init(allocator),
                .typ = typ,
            };
        }

        pub inline fn initCapacity(typ: Enum, num: usize) !Self {
            return .{
                .inner = try std.ArrayList(T).initCapacity(allocator, num),
                .typ = typ,
            };
        }

        pub inline fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub inline fn append(self: *Self, item: T) anyerror!void {
            if (@as(Enum, item) != self.typ) return DynamicListError.InvalidType;
            try self.inner.append(item);
        }

        pub inline fn appendAssumeCapacity(self: *Self, item: T) anyerror!void {
            if (@as(Enum, item) != self.typ) return DynamicListError.InvalidType;
            self.inner.appendAssumeCapacity(item);
        }
    };
}
