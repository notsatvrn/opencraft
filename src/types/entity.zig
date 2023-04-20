pub const EntityMetadata = struct {
    pub fn write(self: EntityMetadata, _: i32) ![]const u8 {
        _ = self;
    }
};
