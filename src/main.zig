const std = @import("std");
const win32 = @import("win32");
const kbm = win32.ui.input.keyboard_and_mouse;
const wam = win32.ui.windows_and_messaging;
const sad = win32.system.stations_and_desktops;
const wt = win32.system.threading;

const print = std.debug.print;
const RegisterHotKey = kbm.RegisterHotKey;
const PeekMessageW = wam.PeekMessageW;
const CreateDesktopA = sad.CreateDesktopA;
const CloseDesktop = sad.CloseDesktop;
const GetThreadDesktop = sad.GetThreadDesktop;
const SwitchDesktop = sad.SwitchDesktop;
const GetCurrentThreadId = wt.GetCurrentThreadId;

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
    CreateBind(kbm.VK_RETURN, "wt"),
};

const desktops = [_][*:0]const u8{
    "desktop no 1",
    "desktop no 2",
};

var baseDesk: sad.HDESK = undefined;

var hdesks = [desktops.len] sad.HDESK{
    undefined,
    undefined,
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

fn createDesktops() void {
    if(GetThreadDesktop(GetCurrentThreadId())) |desk| {
        baseDesk = desk;
    } else {
        print("Unable to get current thread id, exiting...\n", .{});
        std.os.exit(1);
    }


    var i: usize = 0;
    for(desktops) |desktop| {
        const hdesk = CreateDesktopA(
            desktop,
            null,
            null,
            0,
            win32.system.system_services.GENERIC_ALL,
            null,
        );
        if(hdesk) |desk| {
            print("{}\n", .{desk});
            hdesks[i] = desk;
        } else {
            print("Error creating {s} desktop\n", .{desktop});
        }
        i += 1;
    }

    //TODO: this works, just need a better way to manage it
    _ = SwitchDesktop(hdesks[0]);
    std.time.sleep(std.time.ns_per_s * 5);
    _ = SwitchDesktop(baseDesk);
}

fn freeDesktops() void {
    for(hdesks) |hdesk| {
        _ = CloseDesktop(hdesk);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    createDesktops();
    defer freeDesktops();

    registerKeys();
    readMessageLoop(allocator);
}
