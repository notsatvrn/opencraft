const std = @import("std");

pub fn build(b: *std.Build) anyerror!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // DEPENDENCIES

    const unicode = b.dependency("unicode", .{});
    const unicode_mod = unicode.module("unicode");

    const network = b.dependency("network", .{});
    const network_mod = network.module("network");

    // SERVER

    const server = b.addExecutable(.{
        .name = "opencraft_server",
        .root_source_file = .{ .path = "src/server.zig" },
        .target = target,
        .optimize = optimize,
    });

    server.root_module.addImport("unicode", unicode_mod);
    server.root_module.addImport("network", network_mod);
    b.installArtifact(server);

    const run_server_cmd = b.addRunArtifact(server);
    run_server_cmd.step.dependOn(b.getInstallStep());
    const run_server_step = b.step("run_server", "Run an opencraft server");
    run_server_step.dependOn(&run_server_cmd.step);

    // CLIENT

    const client = b.addExecutable(.{
        .name = "opencraft_client",
        .root_source_file = .{ .path = "src/client.zig" },
        .target = target,
        .optimize = optimize,
    });

    client.root_module.addImport("unicode", unicode_mod);
    client.root_module.addImport("network", network_mod);
    b.installArtifact(client);

    const run_client_cmd = b.addRunArtifact(client);
    run_client_cmd.step.dependOn(b.getInstallStep());
    const run_client_step = b.step("run_client", "Run an opencraft client");
    run_client_step.dependOn(&run_client_cmd.step);

    // TESTS

    const tests = b.addTest(.{
        .name = "test",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    tests.root_module.addImport("unicode", unicode_mod);
    tests.root_module.addImport("network", network_mod);
    const tests_step = b.step("test", "Run all tests");
    tests_step.dependOn(&b.addRunArtifact(tests).step);
}
