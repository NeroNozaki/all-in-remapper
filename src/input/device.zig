const std = @import("std");
const c = @import("../include/linux_input.h.zig");
const linux = std.os.linux;

pub const InputDevice = struct {
    const Self = @This();
    name: []const u8,
    path: []const u8,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, device_entry: std.Io.Dir.Entry) !Self {
        const path = try std.fmt.allocPrint(allocator, "/dev/input/{s}", .{device_entry.name});
        errdefer allocator.free(path);

        const file = try std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only });
        defer file.close(io);
        var buf: [256]u8 = undefined;

        const result = linux.ioctl(file.handle, c.EVIOCGNAME(buf.len), @intFromPtr(&buf));
        if (linux.errno(result) != .SUCCESS) { return error.DeviceNameUnavailable; }
        // const result = c.ioctl(file.handle, c.EVIOCGNAME(buf.len), &buf);
        // if (result < 0) { return error.DeviceNameUnavailable; }

        const name = try allocator.dupe(u8, buf[0..@intCast(result)]);
        errdefer allocator.free(name);

        return .{ .name = name, .path = path };
    }

    pub fn deinit(this: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(this.name);
        allocator.free(this.path);
    }
};
