const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Keybind = struct {
    const Special = enum {
        None,
        Comma,
        Plus,
        Space,
        Escape,
        Return,
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
    while (try parseKeybind(&state, ally)) {}
    return state.keybinds.toOwnedSlice();
}

pub fn parseFile(path: []const u8, ally: Allocator) ![]Keybind {
    const src = try std.fs.cwd().readFileAlloc(ally, path, 1024 * 1024 * 8);
    defer ally.free(src);
    return parse(src, ally);
}

fn parseKeybind(state: *ParseState, ally: Allocator) !bool {
    skipWhitespace(state);
    if (state.eof()) {
        return false;
    }

    var keybind = Keybind{};

    // parse bind
    while (true) {
        skipHorizontalWhitespace(state);
        if (state.eof() or state.get() == '\n') {
            break;
        }
        const str = readString(state);

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

        if (state.get() == '+') {
            state.next();
            continue;
        }
    }
    skipVerticalWhitespace(state);
    skipHorizontalWhitespace(state);
    if (state.eof()) {
        return false;
    }

    const begin = state.index;
    while (!state.eof() and state.get() != '\n') {
        state.next();
    }
    const end = state.index;

    const line = state.src[begin..end];
    keybind.action = try ally.dupe(u8, line);
    try state.keybinds.append(keybind);
    return true;
}

fn setString(keybind: *Keybind, str: []const u8) bool {
    // modifier
    if (setModifier(keybind, str)) {
        return true;
    }

    if (keybind.special != Keybind.Special.None and keybind.key != 0) {
        return false;
    }

    // single byte key
    if (str.len == 1) {
        keybind.key = std.ascii.toUpper(str[0]);
        return true;
    }

    // multi byte key
    if (setSpecial(keybind, str)) {
        return true;
    }

    return false;
}

fn setModifier(keybind: *Keybind, str: []const u8) bool {
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

fn setSpecial(keybind: *Keybind, str: []const u8) bool {
    const specials = std.enums.values(Keybind.Special);
    for (specials) |spec| {
        const enumStr = @tagName(spec);
        if (std.ascii.eqlIgnoreCase(str, enumStr)) {
            keybind.special = spec;
            return true;
        }
    }
    return false;
}

fn readString(state: *ParseState) []const u8 {
    const begin = state.index;
    while (!state.eof()) {
        switch (state.get()) {
            '+', ',', '{', '}', ' ', '\t', '\n', '\r' => break,
            else => state.next(),
        }
    }
    const end = state.index;
    return state.src[begin..end];
}

fn skipHorizontalWhitespace(state: *ParseState) void {
    while (!state.eof()) {
        switch (state.get()) {
            ' ', '\t' => state.next(),
            else => return,
        }
    }
}

fn skipVerticalWhitespace(state: *ParseState) void {
    while (!state.eof()) {
        switch (state.get()) {
            '\n', '\r' => state.next(),
            else => return,
        }
    }
}

fn skipWhitespace(state: *ParseState) void {
    while (!state.eof()) {
        switch (state.get()) {
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

    pub fn get(self: *const ParseState) u8 {
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

fn free(k: []Keybind, a: Allocator) void {
    for (k) |j| {
        j.deinit(a);
    }
    a.free(k);
}

test "parse basic command special key" {
    const ally = std.testing.allocator;
    const src = "alt + return\n  wt";

    const result = try parse(src, ally);
    defer free(result, ally);

    try expectEqual(@as(usize, 1), result.len);
    try expectEqual(@as(u1, 1), result[0].alt);
    try expectEqual(Keybind.Special.Return, result[0].special);
    try expectEqualStrings("wt", result[0].action);
}

test "parse basic command regular key" {
    const ally = std.testing.allocator;
    const src = "\n\nalt+d\n\ntmenu run\n\n";

    const result = try parse(src, ally);
    defer free(result, ally);

    try expectEqual(@as(usize, 1), result.len);
    try expectEqual(@as(u1, 1), result[0].alt);
    try expectEqual(Keybind.Special.None, result[0].special);
    try expectEqual(@as(u32, 'd'), result[0].key);
    try expectEqualStrings("tmenu run", result[0].action);
}

test "parse command with multiple modifiers" {
    const ally = std.testing.allocator;
    const src = "alt + shift + e\n\texit";

    const result = try parse(src, ally);
    defer free(result, ally);

    try expectEqual(@as(usize, 1), result.len);
    try expectEqual(@as(u1, 1), result[0].alt);
    try expectEqual(@as(u1, 1), result[0].shift);
    try expectEqual(Keybind.Special.None, result[0].special);
    try expectEqual(@as(u32, 'e'), result[0].key);
    try expectEqualStrings("exit", result[0].action);
}
