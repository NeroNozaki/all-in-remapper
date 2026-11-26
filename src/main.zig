const std = @import("std");
const backend = @import("backend");
const device = @import("device");
const help = @import("build_options").help_text;
const cmd = @import("cmd");

const Allocator = std.mem.Allocator;
var debug_allocator = std.heap.DebugAllocator(.{}){};
const dba = debug_allocator.allocator();
const InputDevice = backend.InputDevice;
const Monitor = backend.Monitor;

const CommandType = enum {
    help,
    devices,
    monitor,
    unknown,
    @"test",
};

pub fn main(init: std.process.Init) !void {
    defer _ = debug_allocator.deinit();
    const arena = init.arena.allocator();
    const io = init.io;
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    var stdin_reader = std.Io.File.stdin().reader(io, &.{});
    const stdout = &stdout_writer.interface;
    const stdin = &stdin_reader.interface;
    _ = stdin;
    // _ = stdout;

    var command: CommandType = .unknown;

    var args = try init.minimal.args.toSlice(arena);
    args = args[1..];

    if (args.len < 1 or std.mem.eql(u8, args[0], "--help")) {
        command = .help;
    }else if (std.mem.eql(u8, args[0], "devices")) {
        command = .devices;
    } else if (std.mem.eql(u8, args[0], "monitor")) {
        command = .monitor;
    } else if (std.mem.eql(u8, args[0], "test")) {
        command = .@"test";
    } else {
        command = .unknown;
    }

    var devices: []InputDevice = undefined;

    if (command == .help) {
        try stdout.print("{s}\n", .{help});
        return;
    }

    devices = try device.list(dba, io);
    defer {
        for (devices) |*dev| dev.deinit(dba, io);
        dba.free(devices);
    }

    switch (command) {
        .help => {
        },
        .devices => try cmd.devices.run(args[1..], stdout, devices),
        .monitor => try Monitor.listenAll(stdout, dba, io, devices),
        .@"test" => try @"test"(devices),
        else => {
            std.debug.print("unsupported command.\n", .{});
        }
    }

    std.debug.print("args:", .{});
    for (args) |arg| {
        std.debug.print(" {s}", .{arg});
    }
    std.debug.print("\n", .{});
}

fn listDevices(stdout: *std.Io.Writer, devices: []InputDevice) !void {
    for (devices, 0..) |*dev, i| {
        if (i != 0) try stdout.writeByte('\n');
        try stdout.print("{s}:\n", .{dev.displayName()});
        try stdout.print("  path: {s}\n", .{dev.path});
        try stdout.print("  id:\n", .{});
        try stdout.print("    bustype: {d}\n", .{dev.id.?.bustype});
        try stdout.print("    vendor: {d}\n", .{dev.id.?.vendor});
        try stdout.print("    product: {d}\n", .{dev.id.?.product});
        try stdout.print("    version: {d}\n", .{dev.id.?.version});
        try stdout.print("  physical location: {s}\n", .{dev.phys orelse "unknown"});
        try stdout.writeByte('\n');
    }
}

fn @"test"(devices: []InputDevice) !void {
    for (devices) |*dev| {
        std.debug.print("{s}:\n", .{dev.displayName()});
        std.debug.print("  path: {s}\n", .{dev.path});
        std.debug.print("  id:\n", .{});
        std.debug.print("    bustype: {d}\n", .{dev.id.?.bustype});
        std.debug.print("    vendor: {d}\n", .{dev.id.?.vendor});
        std.debug.print("    product: {d}\n", .{dev.id.?.product});
        std.debug.print("    version: {d}\n", .{dev.id.?.version});
        std.debug.print("  physical location: {s}\n", .{dev.phys orelse "unknown"});
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}
