const std = @import("std");
const win32 = @import("win32");
const kbm = win32.ui.input.keyboard_and_mouse;
const wam = win32.ui.windows_and_messaging;

const print = std.debug.print;
const RegisterHotKey = kbm.RegisterHotKey;
const PeekMessageW = wam.PeekMessageW;

const modifier = kbm.HOT_KEY_MODIFIERS.ALT;

const KeyBind = struct {
    key: u32,
    action: []const u8,
};

fn CreateBind(key: kbm.VIRTUAL_KEY, action: []const u8) KeyBind {
    return KeyBind{
        .key = @enumToInt(key),
        .action = action,
    };
}

const binds = [_]KeyBind{
    CreateBind(kbm.VK_R, "explorer"),
    CreateBind(kbm.VK_T, "wt"),
};

fn registerKeys() void {
    var id: i32 = 1;
    for(binds) |bind| {
        _ = RegisterHotKey(
            null,       // hwnd
            id,         // id
            modifier,   // modifier(s)
            bind.key,   // virtual key-code
        );
        id += 1;
    }
}

fn spawn(allocator: std.mem.Allocator, what: []const u8) void {
    const args = [_][]const u8{what};
    const proc = std.ChildProcess.init(&args, allocator) catch |err| {
        print("Error spawning process: {s}\n", .{@errorName(err)});
        return;
    };
    defer proc.deinit();
    proc.spawn() catch |err| {
        print("Error spawning process: {s}\n", .{@errorName(err)});
    };
}

fn readMessageLoop(allocator: std.mem.Allocator) void {
    var msg: wam.MSG = undefined;

    while(true) {
        _ = PeekMessageW(
            &msg,   // message pointer
            null,   // hwnd
            0,      // msgFilterMin
            0,      // msgFilterMax
            wam.PEEK_MESSAGE_REMOVE_TYPE.REMOVE,       // removeMsg
        );

        const id = msg.wParam;
        if(id > 0 and id - 1 < binds.len) {
            const index = id - 1;
            //binds[index].action(allocator);
            spawn(allocator, binds[index].action);
        }

        const amount = std.time.ns_per_ms * 10;
        std.time.sleep(amount);
        msg.wParam = 0;
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    registerKeys();
    readMessageLoop(allocator);
}
