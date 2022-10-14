const std = @import("std");
const win32base = @import("win32");
const win32 = struct {
    usingnamespace win32base.ui.input.keyboard_and_mouse;
    usingnamespace win32base.ui.windows_and_messaging;
};

const debug = std.debug;
const log = std.log;
const modifier = win32.HOT_KEY_MODIFIERS.ALT;

const KeyBind = struct {
    key: u32,
    modSum: u32,
    action: []const u8,
};

fn createBind(key: win32.VIRTUAL_KEY, modifier1: ?win32.HOT_KEY_MODIFIERS, modifier2: ?win32.HOT_KEY_MODIFIERS, action: []const u8) KeyBind {
    var sum: u32 = 0;
    if (modifier1) |mod| {
        sum |= @enumToInt(mod);
    }
    if (modifier2) |mod| {
        sum |= @enumToInt(mod);
    }
    return KeyBind{
        .key = @enumToInt(key),
        .modSum = sum,
        .action = action,
    };
}

// add keybindings here
const binds = [_]KeyBind{
    createBind(win32.VK_E, null, null, "explorer"),
    createBind(win32.VK_RETURN, null, null, "wt"),
    createBind(win32.VK_D, null, null, "tmenu run"),
    createBind(win32.VK_O, null, null, "tmenu open"),
    createBind(win32.VK_E, win32.HOT_KEY_MODIFIERS.SHIFT, null, "exit"),
};

fn registerKeys() void {
    log.info("Registering keys", .{});
    for (binds) |bind, index| {
        if (win32.RegisterHotKey(
            null, // hwnd
            @intCast(i32, index) + 1, // id
            @intToEnum(win32.HOT_KEY_MODIFIERS, @enumToInt(modifier) | bind.modSum), // modifier(s)
            bind.key, // virtual key-code
        ) == 0) {
            @panic("Unable to register hotkey");
        }
    }
}

fn unregisterKeys() void {
    log.info("Unregistering keys", .{});
    for (binds) |_, index| {
        _ = win32.UnregisterHotKey(null, @intCast(i32, index) + 1);
    }
}

fn spawn(allocator: std.mem.Allocator, what: []const u8) void {
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

fn readMessageLoop(allocator: std.mem.Allocator) void {
    var msg: win32.MSG = undefined;

    while (true) {
        _ = win32.PeekMessageW(
            &msg, // message pointer
            null, // hwnd
            0, // msgFilterMin
            0, // msgFilterMax
            win32.PEEK_MESSAGE_REMOVE_TYPE.REMOVE, // removeMsg
        );

        const id = msg.wParam;
        if (id > 0 and id - 1 < binds.len) {
            const index = id - 1;
            if (std.mem.eql(u8, binds[index].action, "exit")) {
                return;
            }
            spawn(allocator, binds[index].action);
            msg = std.mem.zeroes(win32.MSG);
        }

        const amount = std.time.ns_per_ms * 10;
        std.time.sleep(amount);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        debug.assert(!gpa.deinit());
    }

    unregisterKeys();
    registerKeys();
    defer unregisterKeys();
    log.info("Starting message loop", .{});
    readMessageLoop(allocator);
}

comptime {
    _ = @import("config.zig");
}
