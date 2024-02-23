// Higher-level wrapper over the std.fs API.

const impl = if (@import("builtin").target.isWasm()) @import("fs/wasm.zig") else @import("fs/native.zig");
pub usingnamespace impl;

test {
    _ = impl;
}
