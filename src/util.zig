// Miscellaneous utilities.

const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const Version = enum(i32) {
    v1_8_x = 47,
    v1_12_2 = 340,
    v1_13 = 393,

    pub inline fn toString(self: Version) []const u8 {
        return switch (self) {
            .v1_8_x => "1.8.x",
            .v1_12_2 => "1.12.2",
            .v1_13 => "1.13",
        };
    }

    pub inline fn toMinSemVer(self: Version) std.SemanticVersion {
        return switch (self) {
            .v1_8_x => comptime std.SemanticVersion.parse("1.8.0"),
            .v1_12_2 => comptime std.SemanticVersion.parse("1.12.2"),
            .v1_13 => comptime std.SemanticVersion.parse("1.13.0"),
        };
    }

    pub inline fn toMaxSemVer(self: Version) std.SemanticVersion {
        return switch (self) {
            .v1_8_x => comptime std.SemanticVersion.parse("1.8.9"),
            .v1_12_2 => comptime std.SemanticVersion.parse("1.12.2"),
            .v1_13 => comptime std.SemanticVersion.parse("1.13.0"),
        };
    }
};

pub fn appendStrings(strings: [][]u8) ![]u8 {
    // avoid resizing (perf)
    var size: usize = 0;
    for (strings) |string| {
        size += string.len;
    }

    var arraylist = try std.ArrayList(u8).initCapacity(allocator, size);

    for (strings) |string| {
        arraylist.appendSliceAssumeCapacity(string);
    }

    return arraylist.toOwnedSlice();
}

// more accurate than the one in standard library, also unsigned
pub inline fn milliTimestamp() u64 {
    return @as(u64, @intCast(@divFloor(@as(u128, @intCast(std.time.nanoTimestamp())), std.time.ns_per_ms)));
}
