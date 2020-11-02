fn escape(comptime literal: []const u8) []const u8 {
    return "\x1b[" ++ literal;
}

// zig fmt: off
pub const Black        = "30";
pub const Red          = "31";
pub const Green        = "32";
pub const Yellow       = "33";
pub const Blue         = "34";
pub const Magenta      = "35";
pub const Cyan         = "36";
pub const LightGray    = "37";
pub const Default      = "39";
pub const DarkGray     = "90";
pub const LightRed     = "91";
pub const LightGreen   = "92";
pub const LightYellow  = "93";
pub const LightBlue    = "94";
pub const LightMagenta = "95";
pub const LightCyan    = "96";
pub const White        = "97";
// zig fmt: on

pub fn Reset() []const u8 {
    return escape("0m");
}

pub fn Foreground(comptime color: []const u8) []const u8 {
    return escape(color ++ "m");
}
