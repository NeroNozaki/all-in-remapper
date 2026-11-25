const std = @import("std");
const help_text = @embedFile("docs/help.txt");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linux_input_module = b.createModule(.{
        .root_source_file = b.path("src/include/linux_input.h.zig"),
        .target = target,
        .optimize = optimize,
    });

    const backend_module = b.createModule(.{
        .root_source_file = b.path("src/backend/backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{
            .name = "linux_input",
            .module = linux_input_module,
        }},
    });

    const device_module = b.createModule(.{
        .root_source_file = b.path("src/input/device.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{
            .name = "backend",
            .module = backend_module,
        }},
    });

    const exe = b.addExecutable(.{
        .name = "air",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "backend",
                    .module = backend_module,
                },

                .{
                    .name = "device",
                    .module = device_module,
                },
            },
        }),
    });

    exe.root_module.linkSystemLibrary("c", .{
        .preferred_link_mode = .static,
    });

    const options = b.addOptions();
    options.addOption([]const u8, "help_text", help_text);

    exe.root_module.addOptions("build_options", options);

    b.installArtifact(exe);


    const run_step = b.step("run", "Run the program");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    std.debug.print("program compiled successfully ^_^\n", .{});
}
