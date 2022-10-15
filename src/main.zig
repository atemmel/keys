const std = @import("std");
const Allocator = std.mem.Allocator;
const win32base = @import("win32");
const win32 = struct {
    usingnamespace win32base.ui.input.keyboard_and_mouse;
    usingnamespace win32base.ui.windows_and_messaging;
};

const config = @import("config.zig");
const FileWatcher = @import("file_watcher.zig").FileWatcher;
const windows_map = @import("windows_map.zig");

const log = std.log;

var keybinds: []config.Keybind = &[_]config.Keybind{};

fn registerKeys(keys: []config.Keybind) void {
    log.info("Registering keys", .{});

    for (keys) |bind, index| {
        const id: i32 = @intCast(i32, index) + 1;
        const mod = windows_map.mapBindToModifier(bind);
        const key = windows_map.mapBindToVCode(bind);

        if (win32.RegisterHotKey(
            null,
            id,
            mod,
            key,
        ) == 0) {
            @panic("Unable to register hotkey");
        }

        log.info("Registered keycode 0x{x} to '{s}' (id: {})", .{ key, bind.action, id });
    }
}

fn unregisterKeys(keys: []config.Keybind) void {
    log.info("Unregistering keys", .{});
    for (keys) |_, index| {
        _ = win32.UnregisterHotKey(null, @intCast(i32, index) + 1);
    }
}

fn spawn(allocator: Allocator, what: []const u8) void {
    var it = std.mem.tokenize(u8, what, " ");
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    while (it.next()) |slice| {
        args.append(slice) catch unreachable;
    }
    log.info("trying to spawn: {s}", .{args.items});
    var proc = std.ChildProcess.init(args.items, allocator);
    proc.spawn() catch |err| {
        log.err("Error spawning process: {s}\n", .{@errorName(err)});
    };
}

fn readMessageLoop(ally: Allocator, config_path: []const u8) void {
    var msg: win32.MSG = undefined;
    var file_watcher = FileWatcher.init(config_path);

    while (true) {
        _ = win32.PeekMessageW(
            &msg, // message pointer
            null, // hwnd
            0, // msgFilterMin
            0, // msgFilterMax
            win32.PEEK_MESSAGE_REMOVE_TYPE.REMOVE, // removeMsg
        );

        const id = msg.wParam;
        if (id > 0 and id - 1 < keybinds.len) {
            const index = id - 1;
            log.info("Keybind {} pressed!", .{index});
            const keybind = keybinds[index];
            if (std.mem.eql(u8, keybind.action, "exit")) {
                return;
            }
            spawn(ally, keybind.action);
            msg = std.mem.zeroes(win32.MSG);
        }

        const amount = std.time.ns_per_ms * 10;
        std.time.sleep(amount);

        const file_is_updated = file_watcher.poll() catch |e| {
            log.err("Error reading status of config: {s}\n", .{@errorName(e)});
            continue;
        };

        if (file_is_updated) {
            _ = updateConfigFromFile(config_path, ally);
        }
    }
}

fn freeKeybinds(keys: []config.Keybind, ally: Allocator) void {
    for (keys) |k| {
        k.deinit(ally);
    }
    ally.free(keys);
}

fn updateConfigFromFile(config_file: []const u8, ally: Allocator) bool {
    var success = true;
    var old_binds = keybinds;

    unregisterKeys(old_binds);
    log.info("Reading config from {s}...", .{config_file});
    if (config.parseFile(config_file, ally)) |new_binds| {
        keybinds = new_binds;
    } else |err| {
        log.err("Error reading config from {s}: {s}", .{ config_file, @errorName(err) });
        keybinds = old_binds;
        old_binds = keybinds[0..0];
        success = false;
    }
    registerKeys(keybinds);
    freeKeybinds(old_binds, ally);
    return success;
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();
    defer {
        unregisterKeys(keybinds);
        freeKeybinds(keybinds, ally);
        std.debug.assert(!gpa.deinit());
    }

    const alloced_args = try std.process.argsAlloc(ally);
    defer std.process.argsFree(ally, alloced_args);
    const args = alloced_args[0..alloced_args.len];

    var config_file: []const u8 = "~/.key.binds";
    if (args.len > 1) {
        config_file = args[1][0..];
    }

    if (!updateConfigFromFile(config_file, ally)) {
        log.err("Unable to read from config, exiting...", .{});
        return;
    }
    log.info("Starting message loop", .{});
    readMessageLoop(ally, config_file);
}

comptime {
    _ = @import("config.zig");
}
