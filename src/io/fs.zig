// Higher-level wrapper over the std.fs API.

const std = @import("std");

const allocator = @import("../global.zig").allocator;

// COMMON

pub fn absolutePath(path: []const u8) ![]const u8 {
    return if (std.fs.path.isAbsolute(path)) path else blk: {
        var cwd = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd);
        break :blk try std.fs.path.join(allocator, &[2][]const u8{ cwd, path });
    };
}

// FILE

pub const FileError = error{
    FileNotFound,
    FileAlreadyExists,
};

pub const File = struct {
    file: std.fs.File,

    pub inline fn exists(path: []const u8) bool {
        if (std.fs.accessAbsolute(absolutePath(path) catch return false, .{})) {
            return true;
        } else |err| return err != std.fs.Dir.AccessError.FileNotFound;
    }

    pub inline fn create(path: []const u8) anyerror!File {
        if (File.exists(path)) return FileError.FileAlreadyExists;
        return .{ .file = try std.fs.createFileAbsolute(try absolutePath(path), .{ .read = true }) };
    }

    pub inline fn createWithContents(path: []const u8, bytes: []const u8) anyerror!File {
        if (File.exists(path)) return FileError.FileAlreadyExists;
        var file = try std.fs.createFileAbsolute(try absolutePath(path), .{ .read = true });
        try file.writeAll(bytes);
        return .{ .file = file };
    }

    pub inline fn open(path: []const u8) anyerror!File {
        if (!File.exists(path)) return FileError.FileNotFound;
        return .{ .file = try std.fs.openFileAbsolute(try absolutePath(path), .{ .mode = .read_write }) };
    }

    pub inline fn write(self: File, bytes: []const u8) !void {
        try self.file.writeAll(bytes);
    }

    pub inline fn read(self: File) ![]const u8 {
        var buf_reader = std.io.bufferedReader(self.file.reader());
        var in_stream = buf_reader.reader();

        return in_stream.readAllAlloc(allocator, 1024 * 1024 * 1024);
    }

    pub inline fn close(self: File) void {
        self.file.close();
    }
};
