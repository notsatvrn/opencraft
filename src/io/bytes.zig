const std = @import("std");

const allocator = @import("../global.zig").allocator;

pub fn appendByteSlices(slices: [][]u8) ![]u8 {
    var arraylist = std.ArrayList(u8).init(allocator);
    defer arraylist.deinit();

    for (slices) |slice| {
        arraylist.appendSlice(slice);
    }

    return arraylist.toOwnedSlice();
}
