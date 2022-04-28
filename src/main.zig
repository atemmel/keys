const std = @import("std");
const win32 = @import("win32");
const kbm = win32.ui.input.keyboard_and_mouse;
const wam = win32.ui.windows_and_messaging;
const sad = win32.system.stations_and_desktops;
const st = win32.system.threading;
const se = win32.system.environment;

const print = std.debug.print;
const RegisterHotKey = kbm.RegisterHotKey;
const PeekMessageW = wam.PeekMessageW;
const GetMessageW = wam.GetMessageW;
const CreateDesktopW = sad.CreateDesktopW;
const CloseDesktop = sad.CloseDesktop;
const OpenDesktop = sad.OpenDesktop;
const GetThreadDesktop = sad.GetThreadDesktop;
const SwitchDesktop = sad.SwitchDesktop;
const SetThreadDesktop = sad.SetThreadDesktop;
const GetCurrentThreadId = st.GetCurrentThreadId;
const ExpandEnvironmentStrings = se.ExpandEnvironmentStrings;
const CreateProcess = st.CreateProcess;
const STARTUPINFOW = st.STARTUPINFOW;
const PROCESS_INFORMATION = st.PROCESS_INFORMATION;

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
    CreateBind(kbm.VK_E, "explorer"),
    CreateBind(kbm.VK_RETURN, "wt"),
};

const desktops = [_][:0]const u16{
    std.unicode.utf8ToUtf16LeStringLiteral("desktop_no_1"),
    //std.unicode.utf8ToUtf16LeStringLiteral("desktop_no_2"),
};

var baseDesk: sad.HDESK = undefined;

var hdesks = [desktops.len]sad.HDESK{
    undefined,
    //undefined,
};

var explorerPath: [std.fs.MAX_PATH_BYTES:0]u16 = undefined;

fn registerKeys() void {
    var id: i32 = 1;
    for (binds) |bind| {
        _ = RegisterHotKey(
            null, // hwnd
            id, // id
            modifier, // modifier(s)
            bind.key, // virtual key-code
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

    while (true) {
        _ = PeekMessageW(
            &msg, // message pointer
            null, // hwnd
            0, // msgFilterMin
            0, // msgFilterMax
            wam.PEEK_MESSAGE_REMOVE_TYPE.REMOVE, // removeMsg
        );

        const id = msg.wParam;
        if (id > 0 and id - 1 < binds.len) {
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
    if (GetThreadDesktop(GetCurrentThreadId())) |desk| {
        baseDesk = desk;
    } else {
        print("Unable to get current thread id, exiting...\n", .{});
        std.os.exit(1);
    }

    const flags = win32.system.system_services.GENERIC_ALL;

    for (desktops) |desktop, i| {
        const hdesk = CreateDesktopW(
            desktop,
            null,
            null,
            0,
            flags,
            null,
        );
        if (hdesk) |desk| {
            hdesks[i] = desk;
            print("{u}: {} {}\n", .{ desktop, desk, hdesks[i] });
        } else {
            print("Error creating {any} desktop\n", .{desktop});
        }
    }

    //TODO: this works, just need a better way to manage it
    //_ = SwitchDesktop(hdesks[0]);

    var deskName: [desktops[0].len:0]u16 = undefined;
    std.mem.copy(u16, &deskName, desktops[0]);

    var startInfo = std.mem.zeroes(STARTUPINFOW);
    startInfo.cb = @sizeOf(STARTUPINFOW);
    startInfo.lpDesktop = &deskName;

    var procInfo = std.mem.zeroes(PROCESS_INFORMATION);

    print("SetThreadDesktop: {}\n", .{SetThreadDesktop(hdesks[0])});
    const result = CreateProcess(
        &explorerPath,
        null,
        null,
        null,
        0,
        st.PROCESS_CREATION_FLAGS.initFlags(.{}),
        null,
        null,
        &startInfo,
        &procInfo,
    );
    registerKeys();
    print("SetThreadDesktop: {}\n", .{SetThreadDesktop(baseDesk)});
    print("CreateProcess: {}, desktop: {u}\n", .{ result, deskName });

    print("SwitchDesktop: {}\n", .{SwitchDesktop(hdesks[0])});
    const seconds = std.time.ns_per_s;
    std.time.sleep(10 * seconds);
    print("SwitchDesktop: {}\n", .{SwitchDesktop(baseDesk)});
}

fn freeDesktops() void {
    for (hdesks) |hdesk| {
        _ = CloseDesktop(hdesk);
    }
}

fn setExplorerPath() void {
    const str = std.unicode.utf8ToUtf16LeStringLiteral("%windir%\\explorer.exe");
    const result = ExpandEnvironmentStrings(
        str,
        &explorerPath,
        std.fs.MAX_PATH_BYTES - 1,
    );
    explorerPath[result] = 0;
    print("setExplorerPath: {}, {u}\n", .{ result, explorerPath[0..result] });
}

pub fn createHiddenDesktop(name: [:0]u16) ?sad.HDESK {
    var explorer_path: [std.fs.MAX_PATH_BYTES:0]u16 = undefined;
    var original_desktop: sad.HDESK = undefined;
    var hidden_desktop: ?sad.HDESK = null;
    var startInfo = std.mem.zeroes(STARTUPINFOW);
    var procInfo = std.mem.zeroes(PROCESS_INFORMATION);

    const path = std.unicode.utf8ToUtf16LeStringLiteral("%windir%\\explorer.exe");
    _ = ExpandEnvironmentStrings(path, &explorer_path, std.fs.MAX_PATH_BYTES - 1);

    const flags = win32.system.system_services.GENERIC_ALL;
    hidden_desktop = OpenDesktop(name, 0, 0, flags);
    if (hidden_desktop == null) {
        hidden_desktop = CreateDesktopW(name, null, null, 0, flags, null);
        if (hidden_desktop != null) {
            if (GetThreadDesktop(GetCurrentThreadId())) |hdesk| {
                original_desktop = hdesk;
            } else {
                @panic("Could not get current desktop\n");
            }
            if (SetThreadDesktop(hidden_desktop.?) != 0) {
                startInfo.cb = @sizeOf(STARTUPINFOW);
                startInfo.lpDesktop = name;

                _ = CreateProcess(
                    &explorer_path,
                    null,
                    null,
                    null,
                    0,
                    st.PROCESS_CREATION_FLAGS.initFlags(.{}),
                    null,
                    null,
                    &startInfo,
                    &procInfo,
                );
                _ = SetThreadDesktop(original_desktop);
            }
        }
    }
    return hidden_desktop;
}

pub fn desktopTest() void {
    //TODO:
    //https://www.codeproject.com/Articles/21352/Virtual-Desktop-A-Simple-Desktop-Management-Tool
    var original_desktop: sad.HDESK = undefined;
    var hidden_desktop: sad.HDESK = undefined;

    const desktop_name = std.unicode.utf8ToUtf16LeStringLiteral("hidden");
    var buff: [64:0]u16 = undefined;
    std.mem.copy(u16, &buff, desktop_name);

    if (createHiddenDesktop(&buff)) |hdesk| {
        hidden_desktop = hdesk;
    } else {
        @panic("Could not create hidden desktop\n");
    }
    if (GetThreadDesktop(GetCurrentThreadId())) |desk| {
        original_desktop = desk;
    } else {
        @panic("Could not get desktop 1\n");
    }

    print("Entering hidden desktop\n", .{});

    _ = SetThreadDesktop(hidden_desktop);

    // alt+e to exit
    if (RegisterHotKey(
        null, // hwnd
        1, // id
        modifier, // modifier(s)
        0x45, // virtual key-code
    ) > 0) {
        _ = SwitchDesktop(hidden_desktop);
        var msg = std.mem.zeroes(wam.MSG);
        while (GetMessageW(&msg, null, 0, 0) != 0) {
            if (msg.message == wam.WM_HOTKEY) {
                print("Exiting hidden desktop\n", .{});
                _ = SwitchDesktop(original_desktop);
                break;
            }
        }
    }

    _ = CloseDesktop(hidden_desktop);
}

pub fn main() anyerror!void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa.allocator();
    //defer {
    //_ = gpa.deinit();
    //}
    //setExplorerPath();
    //createDesktops();
    //defer freeDesktops();

    //registerKeys();
    //readMessageLoop(allocator);
    desktopTest();
}
