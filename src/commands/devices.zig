const std = @import("std");
const backend = @import("backend");
const device = @import("device");
const InputDevice = backend.InputDevice;

const CommandType = enum {
    list,
    unknown,
};

pub fn run(args: []const []const u8, stdout: *std.Io.Writer, devices: []InputDevice) !void {
    var command: CommandType = .unknown;

    if (args.len == 0) {
        std.debug.print("please issue a command.\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[0], "list")) {
        command = .list;
    } else {
        command = .unknown;
    }

    switch (command) {
        .list => try list(stdout, devices),
        .unknown => {
            std.debug.print("unknown command.\n", .{});
            return;
        }
    }
}

fn list(stdout: *std.Io.Writer, devices: []InputDevice) !void {
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
