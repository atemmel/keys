const std = @import("std");

pub const FileWatcher = struct {
    last_change: i128,
    file_to_watch: []const u8,

    pub fn init(file_to_watch: []const u8) FileWatcher {
        return .{
            .last_change = std.time.nanoTimestamp(),
            .file_to_watch = file_to_watch,
        };
    }

    pub fn poll(self: *FileWatcher) !bool {
        const stat = try std.fs.cwd().statFile(self.file_to_watch);
        const last_change = stat.mtime;
        if (last_change <= self.last_change) {
            return false;
        }

        self.last_change = last_change;
        return true;
    }
};
