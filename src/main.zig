const std = @import("std");
const backend = @import("backend");
const device = @import("device");
const help = @import("build_options").help_text;
const Allocator = std.mem.Allocator;

var debug_allocator = std.heap.DebugAllocator(.{}){};
const dba = debug_allocator.allocator();
const InputDevice = backend.InputDevice;
const Monitor = backend.Monitor;

const CommandType = enum {
    help,
    list,
    monitor,
    unknown,
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
    }

    if (args.len != 0) {
        if (std.mem.eql(u8, args[0], "list")) {
            command = .list;
        } else if (std.mem.eql(u8, args[0], "monitor")) {
            command = .monitor;
        } else {
            command = .unknown;
        }
    }

    const devices = try device.list(dba, io);
    defer {
        for (devices) |*dev| dev.deinit(dba, io);
        dba.free(devices);
    }

    switch (command) {
        .help => {
            try stdout.print("{s}\n", .{help});
            return;
        },
        .list => try listDevices(stdout, devices),
        .monitor => try Monitor.listenAll(devices, dba, io),
        else => {
            std.debug.print("unsupported command.\n", .{});
        }
    }

    std.debug.print("\nargs:\n", .{});
    for (args) |arg| {
        std.debug.print("\t{s}\n", .{arg});
    }
}

fn listDevices(stdout: *std.Io.Writer, devices: []InputDevice) !void {
    for (devices, 0..) |*dev, i| {
        if (i != 0) try stdout.writeByte('\n');
        try stdout.writeAll(dev.name);
    }
    try stdout.writeByte('\n');
}
