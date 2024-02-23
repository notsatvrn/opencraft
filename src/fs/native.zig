const std = @import("std");

var allocator = @import("../util.zig").allocator;

// FUNCTIONS

pub fn absolutePath(path: []const u8) ![]const u8 {
    return if (std.fs.path.isAbsolute(path)) path else blk: {
        const cwd = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd);
        break :blk try std.fs.path.join(allocator, &[2][]const u8{ cwd, path });
    };
}

pub inline fn exists(path: []const u8) bool {
    if (std.fs.accessAbsolute(absolutePath(path) catch return false, .{})) {
        return true;
    } else |err| return err != std.fs.Dir.AccessError.FileNotFound;
}

// FILE

pub const FileError = error{
    FileNotFound,
    FileAlreadyExists,
};

pub const File = struct {
    file: std.fs.File,

    pub inline fn new(path: []const u8) anyerror!File {
        if (exists(path)) return FileError.FileAlreadyExists;
        return .{ .file = try std.fs.createFileAbsolute(try absolutePath(path), .{ .read = true }) };
    }

    pub inline fn newWithContents(path: []const u8, data: []const u8) anyerror!File {
        if (exists(path)) return FileError.FileAlreadyExists;
        var file = try std.fs.createFileAbsolute(try absolutePath(path), .{ .read = true });
        try file.writeAll(data);
        return .{ .file = file };
    }

    pub inline fn open(path: []const u8) anyerror!File {
        if (!exists(path)) return FileError.FileNotFound;
        return .{ .file = try std.fs.openFileAbsolute(try absolutePath(path), .{ .mode = .read_write }) };
    }

    pub inline fn write(self: File, data: []const u8) !void {
        try self.file.writeAll(data);
    }

    pub inline fn read(self: File) ![]const u8 {
        var buf_reader = std.io.bufferedReader(self.file.reader());
        var in_stream = buf_reader.reader();

        return in_stream.readAllAlloc(allocator, std.math.maxInt(usize));
    }

    pub inline fn close(self: File) void {
        self.file.close();
    }
};
