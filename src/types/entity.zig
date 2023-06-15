pub const EntityMetadata = struct {
    pub fn write(self: EntityMetadata, version: u16) ![]const u8 {
        _ = version;
        _ = self;
    }
};
