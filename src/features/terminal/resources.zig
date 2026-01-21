const eno_common = @import("eno").common;

const Language = @import("../interpreter/Interpreter.zig").Language;

pub const State = struct {
    is_focused: bool = false,
    frame_counter: usize = 0,
    lang: Language = .plaintext,
    lang_box_is_opened: bool = false,
    selected_lang: i32 = 0,
    /// Status if the button is clickable .
    /// Set `false` to disable.
    active: bool = true,
};

pub const Style = struct {
    font: eno_common.raylib.Font,
    font_size: i32 = 10,
    bg_color: eno_common.raylib.Color = .black,
};
