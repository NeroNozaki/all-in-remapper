const std = @import("std");
const backend = @import("backend");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const InputDevice = backend.InputDevice;
const input_directory = backend.input_directory;

pub fn list(allocator: Allocator, io: Io) ![]InputDevice {
    // this returns an owned slice filled with open InputDevices
    // the caller must deinit all devices and deinit the slice

    const dir = std.Io.Dir.openDirAbsolute(io, input_directory, .{
        .access_sub_paths = true,
        .iterate = true,
    }) catch |err| {
        std.debug.print("this directory does not exist.", .{});
        return err;
    };

    defer dir.close(io);

    var iterator = dir.iterate();

    var devices = std.ArrayList(InputDevice).empty;
    errdefer {
        for (devices.items) |*dev| { dev.deinit(allocator, io); }
        devices.deinit(allocator);
    }

    while (try iterator.next(io)) |entry| {
        if (entry.kind == .character_device and std.mem.startsWith(u8, entry.name, "event")) {
            var dev = try InputDevice.init(allocator, io, entry);
            errdefer dev.deinit(allocator, io);
            try devices.append(allocator, dev);
        }
    }

    return devices.toOwnedSlice(allocator);
}
