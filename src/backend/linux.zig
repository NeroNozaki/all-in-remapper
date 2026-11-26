const std = @import("std");
const c = @import("linux_input");
const linux = std.os.linux;
const posix = std.posix;
const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const input_directory = "/dev/input/";

pub const InputDevice = struct {
    const Self = @This();
    name: ?[]const u8,
    path:  []const u8,
    id:   ?c.input_id,
    phys: ?[]const u8,
    file: ?Io.File = null,

    pub fn init(allocator: Allocator, io: std.Io, device_entry: std.Io.Dir.Entry) !Self {
        if (device_entry.kind != .character_device) { return error.NotCharacterDevice; }

        const path = try std.fmt.allocPrint(allocator, "/dev/input/{s}", .{device_entry.name});
        errdefer allocator.free(path);

        const file = try std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only });
        defer file.close(io);

        var buf: [256]u8 = undefined;

        var name: ?[]const u8 = null;
        errdefer if (name) |n| allocator.free(n);

        var result = linux.ioctl(file.handle, c.EVIOCGNAME(buf.len), @intFromPtr(&buf));
        if (linux.errno(result) == .SUCCESS) {
            name = try allocator.dupe(u8, std.mem.sliceTo(buf[0..result], 0));
        }

        var id: ?c.input_id = null;
        var value: c.input_id = undefined;
        result = linux.ioctl(file.handle, c.EVIOCGID, @intFromPtr(&value));
        if (linux.errno(result) == .SUCCESS) { id = value; }

        var phys: ?[]const u8 = null;
        errdefer if (phys) |p| allocator.free(p);

        result = linux.ioctl(file.handle, c.EVIOCGPHYS(buf.len), @intFromPtr(&buf));
        if (linux.errno(result) == .SUCCESS) {
            phys = try allocator.dupe(u8, std.mem.sliceTo(buf[0..result], 0));
        }


        return .{
            .name = name,
            .path = path,
            .id = id,
            .phys = phys,
        };
    }

    pub fn deinit(this: *Self, allocator: Allocator, io: Io) void {
        this.close(io);
        if (this.name) |name| allocator.free(name);
        allocator.free(this.path);
        if (this.phys) |phys| allocator.free(phys);
    }

    pub fn open(this: *Self, io: Io) !void {
        // doesn't open if device is already open
        if (this.file != null) { return; }
        this.file = try std.Io.Dir.openFileAbsolute(io, this.path, .{ .mode = .read_only });
        // std.debug.print("opened device: {s}\n", .{this.name});
    }

    pub fn close(this: *Self, io: Io) void {
        if (this.file) |f| {
            f.close(io);
            this.file = null;
            // std.debug.print("closed device: {s}\n", .{this.name});
        }
    }

    pub fn listen(this: *Self, allocator: Allocator, io: Io) !void {
        Monitor.listenAll(this[0..1], allocator, io);
    }

    pub fn displayName(this: *const Self) []const u8 {
        return this.name orelse this.path;
    }
};

pub const Monitor = struct {

    pub fn listenAll(stdout: *std.Io.Writer, allocator: Allocator, io: Io, devices: []InputDevice) !void {
        if (devices.len == 0) return error.NoDevices;

        const pollfds = try allocator.alloc(std.posix.pollfd, devices.len);
        defer allocator.free(pollfds);

        for (devices, pollfds) |*dev, *pfd| {
            dev.open(io) catch {
                std.debug.print("couldn't open device {s}\n", .{dev.displayName()});
                pfd.* = .{
                    .fd = -1,
                    .events = 0,
                    .revents = 0,
                };

                continue;
            };

            pfd.* = .{
                .fd = dev.file.?.handle,
                .events = posix.POLL.IN,
                .revents = 0,
            };
        }

        var buf: [64]c.struct_input_event = undefined;
        var prev_index: ?usize = null;

        while (true) {
            _ = try posix.poll(pollfds, -1);

            for (devices, pollfds, 0..) |*dev, *pfd, i| {
                if (pfd.revents & posix.POLL.IN == 0) {
                    pfd.revents = 0;
                    continue;
                }


                const bytes = posix.read(pfd.fd, std.mem.sliceAsBytes(buf[0..])) catch {
                    pfd.revents = 0;
                    continue;
                };
                const count = bytes / @sizeOf(c.struct_input_event);

                for (buf[0..count]) |ev| {
                    if (ev.type == c.EV_KEY or ev.type == c.EV_REL or ev.type == c.EV_ABS) {
                        const changed = prev_index == null or prev_index.? != i;

                        if (changed) {
                            try stdout.print("{s}\n", .{dev.displayName()});
                            prev_index = i;
                        }
                    }
                }

                pfd.revents = 0;
            }
        }
    }
};

