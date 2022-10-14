const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Keybind = struct {
    const Special = enum {
        None,
        Comma,
        Plus,
        Space,
        Escape,
        Enter,
        Backspace,
        Caps,
        Tab,
        F1,
        F2,
        F3,
        F4,
        F5,
        F6,
        F7,
        F8,
        F9,
        F10,
        F11,
        F12,
        PrtSc,
        Insert,
        Delete,
        Home,
        End,
        PgUp,
        PgDn,
    };

    alt: u1 = 0,
    windows: u1 = 0,
    shift: u1 = 0,
    ctrl: u1 = 0,
    key: u32 = 0,
    special: Special = Special.None,
    action: []const u8 = "",

    pub fn deinit(self: *const Keybind, ally: Allocator) void {
        ally.free(self.action);
    }
};

pub fn parse(src: []const u8, ally: Allocator) ![]Keybind {
    var state = ParseState{
        .src = src,
        .keybinds = std.ArrayList(Keybind).init(ally),
    };
    defer state.deinit(ally);
    while (try parseKeybind(&state)) {}
    return state.keybinds.toOwnedSlice();
}

fn parseKeybind(state: *ParseState) !bool {
    dbg("\nidx: {}\n", .{state.index});
    skipWhitespace(state);
    if (state.eof()) {
        return false;
    }

    var keybind = Keybind{};

    // parse bind
    while (true) {
        skipHorizontalWhitespace(state);
        const str = readString(state);
        if (state.eof() or state.get() == '\n') {
            break;
        }

        if (str.len > 0) {
            if (setString(&keybind, str)) {
                continue;
            } else {
                return false;
            }
        }

        if (setModifier(&keybind, str)) {
            continue;
        }

        if (state.peek() == '+') {
            state.next();
            continue;
        }
    }

    try state.keybinds.append(keybind);
    return true;
}

fn setString(keybind: *Keybind, str: []const u8) bool {
    if (setModifier(keybind, str)) {
        return true;
    }

    if (keybind.special != Keybind.Special.None or keybind.key != 0) {
        return false;
    }
    return false;
}

fn setModifier(keybind: *Keybind, modifier: []const u8) bool {
    const str = modifier;

    if (std.ascii.eqlIgnoreCase("alt", str)) {
        keybind.alt = 1;
        return true;
    } else if (std.ascii.eqlIgnoreCase("windows", str)) {
        keybind.windows = 1;
        return true;
    } else if (std.ascii.eqlIgnoreCase("shift", str)) {
        keybind.shift = 1;
        return true;
    } else if (std.ascii.eqlIgnoreCase("ctrl", str)) {
        keybind.ctrl = 1;
        return true;
    }

    return false;
}

fn readString(state: *ParseState) []const u8 {
    const begin = state.index;
    while (!state.eof()) {
        switch (state.peek()) {
            '+', ',', '{', '}', ' ', '\t' => break,
            else => state.next(),
        }
    }
    const end = state.index;
    return state.src[begin..end];
}

fn skipHorizontalWhitespace(state: *ParseState) void {
    while (!state.eof()) {
        switch (state.peek()) {
            ' ', '\t' => state.next(),
            else => return,
        }
    }
}

fn skipWhitespace(state: *ParseState) void {
    while (!state.eof()) {
        switch (state.peek()) {
            '\n', '\r', ' ', '\t' => state.next(),
            else => return,
        }
    }
}

const ParseState = struct {
    src: []const u8,
    keybinds: std.ArrayList(Keybind),
    index: usize = 0,

    pub fn eof(self: *const ParseState) bool {
        return self.index >= self.src.len;
    }

    pub fn peek(self: *const ParseState) u8 {
        return self.src[self.index];
    }

    pub fn next(self: *ParseState) void {
        self.index += 1;
    }

    pub fn deinit(self: *ParseState, ally: Allocator) void {
        for (self.keybinds.items) |k| {
            k.deinit(ally);
        }
        self.keybinds.deinit();
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const dbg = std.debug.print;

fn dump(k: []Keybind) void {
    dbg("{any}\n", .{k});
}

test "parse basic command" {
    const ally = std.testing.allocator;
    const src = "alt + return\n  wt";

    const result = try parse(src, ally);
    defer {
        for (result) |k| {
            k.deinit(ally);
        }
        ally.free(result);
    }

    dump(result);

    try expectEqual(@as(usize, 1), result.len);
    try expectEqual(@as(u1, 1), result[0].alt);
    try expectEqual(@as(u1, 1), result[0].alt);
    try expectEqualStrings("wt", result[0].action);
}
