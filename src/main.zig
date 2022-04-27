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
    action: fn(std.mem.Allocator) void,
};

fn CreateBind(key: kbm.VIRTUAL_KEY, action: fn(std.mem.Allocator)void) KeyBind {
    return KeyBind{
        .key = @enumToInt(key),
        .action = action,
    };
}

const binds = [_]KeyBind{
    CreateBind(kbm.VK_R, openExplorer),
    CreateBind(kbm.VK_T, doSomething),
};

fn registerKeys() void {
    //return RegisterHotKey(
    //null,   // hwnd
    //1,      // id
    //kbm.HOT_KEY_MODIFIERS.ALT,      // modifier
    //@enumToInt(kbm.VK_R),      // virtual key-code
    //);

    var id: i32 = 1;
    for(binds) |bind| {
        _ = RegisterHotKey(
            null,   // hwnd
            id,     // id
            modifier,   // modifier(s)
            bind.key,
        );
        id += 1;
    }
}

fn doSomething(_: std.mem.Allocator) void {
    print("Something is done!\n", .{});
}

fn openExplorer(allocator: std.mem.Allocator) void {
    print("Attempting to open explorer\n", .{});
    const proc = std.ChildProcess.init(&[_][]const u8{
        "explorer",
    }, allocator) catch |err| {
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


        //if(msg.wParam == 1) {
        //print("{}\n", .{msg});
        //}

        const id = msg.wParam;
        if(id > 0 and id - 1 < binds.len) {
            const index = id - 1;
            binds[index].action(allocator);
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
