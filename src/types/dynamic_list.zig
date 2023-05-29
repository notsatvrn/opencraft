const std = @import("std");

var allocator = @import("../global.zig").allocator;

pub const DynamicListError = error{
    InvalidType,
};

// Complete wrapper around std.ArrayList with dynamic union/enum type checking.
// Allows one to have an ArrayList with a union value and only one possible field for all items.
// Due to https://github.com/ziglang/zig/issues/13760, we cannot pull the enum type from the union.
pub fn DynamicList(comptime Union: type, comptime Enum: type) type {
    const Inner = std.ArrayList(Union);

    return struct {
        inner: Inner,
        typ: Enum,

        const Self = @This();

        pub inline fn init(typ: Enum) Self {
            return .{
                .inner = Inner.init(allocator),
                .typ = typ,
            };
        }

        pub inline fn initCapacity(typ: Enum, num: usize) !Self {
            return .{
                .inner = try Inner.initCapacity(allocator, num),
                .typ = typ,
            };
        }

        pub inline fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub inline fn fromOwnedSlice(typ: Enum, slice: Inner.Slice) !Self {
            for (slice) |item| if (@as(Enum, item) != typ) return DynamicListError.InvalidType;

            return .{
                .inner = Inner.fromOwnedSlice(allocator, slice),
                .typ = typ,
            };
        }

        pub inline fn fromOwnedSliceSentinel(typ: Enum, comptime sentinel: Union, slice: [:sentinel]Union) !Self {
            for (slice) |item| if (@as(Enum, item) != typ) return DynamicListError.InvalidType;

            return .{
                .inner = Inner.fromOwnedSliceSentinel(allocator, sentinel, slice),
                .typ = typ,
            };
        }

        pub inline fn toOwnedSlice(self: *Self) !Inner.Slice {
            return self.inner.toOwnedSlice();
        }

        pub inline fn toOwnedSliceSentinel(self: *Self, comptime sentinel: Union) !Inner.SentinelSlice(sentinel) {
            return self.inner.toOwnedSliceSentinel(sentinel);
        }

        pub inline fn clone(self: Self) !Self {
            return .{
                .inner = try Inner.clone(),
                .typ = self.typ,
            };
        }

        pub inline fn append(self: *Self, item: Union) anyerror!void {
            if (@as(Enum, item) != self.typ) return DynamicListError.InvalidType;
            try self.inner.append(item);
        }

        pub inline fn appendAssumeCapacity(self: *Self, item: Union) anyerror!void {
            if (@as(Enum, item) != self.typ) return DynamicListError.InvalidType;
            self.inner.appendAssumeCapacity(item);
        }
    };
}
