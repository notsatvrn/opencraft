// Higher-level wrapper over the std.fs API.

usingnamespace if (@import("builtin").target.isWasm()) @import("fs_wasm.zig") else @import("fs_native.zig");
