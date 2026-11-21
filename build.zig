const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const device_module = b.createModule(.{
        .root_source_file = b.path("src/input/device.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "air",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{
                .name = "device",
                .module = device_module,
            }},
        }),
    });

    exe.root_module.linkSystemLibrary("c", .{
        .preferred_link_mode = .static,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the program");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    std.debug.print("program compiled successfully ^_^\n", .{});
}
