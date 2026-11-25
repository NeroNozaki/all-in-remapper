const builtin = @import("builtin");

const backend = switch(builtin.os.tag) {
    .linux => @import("linux.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("unsupported os."),
};

pub const InputDevice = backend.InputDevice;
pub const Monitor = backend.Monitor;
pub const input_directory = backend.input_directory;
