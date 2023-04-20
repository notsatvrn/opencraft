const std = @import("std");

pub fn build(b: *std.Build) anyerror!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const network = b.addModule("network", .{
        .source_file = .{ .path = "deps/zig-network/network.zig" },
    });

    const zlib = b.addModule("zlib", .{
        .source_file = .{ .path = "deps/zlib.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "opencraft",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("network", network);
    exe.addModule("zlib", zlib);
    b.installArtifact(exe);

    // RUN
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TESTS
    const tests = b.addTest(.{
        .name = "test",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const tests_step = b.step("test", "Run all tests");
    tests_step.dependOn(&b.addRunArtifact(tests).step);
}
