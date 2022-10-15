const win32base = @import("win32");
const win32 = struct {
    usingnamespace win32base.ui.input.keyboard_and_mouse;
};
const Keybind = @import("config.zig").Keybind;

pub fn mapBindToModifier(keybind: Keybind) win32.HOT_KEY_MODIFIERS {
    return win32.HOT_KEY_MODIFIERS.initFlags(.{
        .ALT = keybind.alt,
        .CONTROL = keybind.ctrl,
        .SHIFT = keybind.shift,
        .WIN = keybind.windows,
    });
}

pub fn mapBindToVCode(keybind: Keybind) u32 {
    if (keybind.special != .None) {
        return @enumToInt(switch (keybind.special) {
            .None => unreachable,
            .Comma => win32.VK_OEM_COMMA,
            .Plus => win32.VK_OEM_PLUS,
            .Space => win32.VK_SPACE,
            .Escape => win32.VK_ESCAPE,
            .Return => win32.VK_RETURN,
            .Backspace => win32.VK_BACK,
            .Caps => win32.VK_CAPITAL,
            .Tab => win32.VK_TAB,
            .F1 => win32.VK_F1,
            .F2 => win32.VK_F2,
            .F3 => win32.VK_F3,
            .F4 => win32.VK_F4,
            .F5 => win32.VK_F5,
            .F6 => win32.VK_F6,
            .F7 => win32.VK_F7,
            .F8 => win32.VK_F8,
            .F9 => win32.VK_F9,
            .F10 => win32.VK_F10,
            .F11 => win32.VK_F11,
            .F12 => win32.VK_F12,
            .PrtSc => win32.VK_SNAPSHOT,
            .Insert => win32.VK_INSERT,
            .Delete => win32.VK_DELETE,
            .Home => win32.VK_HOME,
            .End => win32.VK_END,
            .PgUp => win32.VK_PRIOR,
            .PgDn => win32.VK_NEXT,
        });
    }

    return keybind.key;
}
