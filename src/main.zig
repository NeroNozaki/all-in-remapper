const std = @import("std");
const device = @import("input/device.zig");
var debug_allocator = std.heap.DebugAllocator(.{}){};
const dba = debug_allocator.allocator();

pub fn main(init: std.process.Init) !void {
    defer _ = debug_allocator.deinit();
    const io = init.io;
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    var stdin_reader = std.Io.File.stdin().reader(io, &.{});
    const stdout = &stdout_writer.interface;
    const stdin = &stdin_reader.interface;
    _ = stdin;
    // _ = stdout;
    // var in_buf: [100]u8 = undefined;

    // const cwd = std.Io.Dir.cwd();
    // const length =  try std.process.currentPath(io, &in_buf);
    // const cwd_path = in_buf[0..length];

    const input_directory = "/dev/input/";

    const dir = std.Io.Dir.openDirAbsolute(io, input_directory, .{
        .access_sub_paths = true,
        .iterate = true,
    }) catch |err| {
        std.debug.print("this directory does not exist.", .{});
        return err;
    };

    var iterator = dir.iterate();

    var devices = std.ArrayList(device.InputDevice).empty;
    defer devices.deinit(dba);

    while (try iterator.next(io)) |entry| {
        if (entry.kind == .character_device and std.mem.startsWith(u8, entry.name, "event")) {
            const dev = try device.InputDevice.init(dba, io, entry);
            try devices.append(dba, dev);
        }
    }

    defer {
        for (devices.items) |dev| {
            dev.deinit(dba);
        }
    }

    for (devices.items) |dev| {
        try stdout.print("{s}\n", .{dev.name});
    }
}

fn getDevices() !void {
    // 1. discover input devices by listing out /dev/input/
    // 2. identify devices using ioctl() and EVIOCGNAME


    // for (devices.items) |device| {
    //     try stdout.print("{s}\n", .{device.name});
    // }

    // const device_path = input_directory ++ devices.items[0].name;

    // for (devices.items) |entry| {
    //     const device = dir.openFile(io, entry.name, .{
    //         .mode = .read_only,
    //     }) catch |err| {
    //         std.debug.print("this device doesn't exist\n", .{});
    //         return err;
    //     };
    //
    //     defer device.close(io);
    //
    //     var name: [256]u8 = undefined;
    //     var names = std.ArrayList([]u8).empty;
    //     defer names.deinit(dba);
    //     const result = c.ioctl(device.handle, c.EVIOCGNAME(name.len), &name);
    //
    //     if (result <= 0) {
    //         std.debug.print("failed to read {s}\n", .{entry.name});
    //         continue;
    //     }
    //
    //     names.append(dba, name[0..@intCast(result)]);
    // }
}

fn monitorDevices() !void {
    // 3. monitor devices using poll()
    // 4. read input from devices
    //    kernel provides inputs in the form of struct input_event
}
