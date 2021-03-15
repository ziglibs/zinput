const std = @import("std");
const ansi = @import("ansi.zig");
const Writer = std.fs.File.Writer;

const targeting_windows = (std.builtin.os.tag == .windows);
const windows = std.os.windows;
const wincon = struct {
    pub extern "kernel32" fn GetConsoleMode(h_console: windows.HANDLE, mode: *windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
    pub extern "kernel32" fn GetConsoleScreenBufferInfo(h_console: windows.HANDLE, info: *windows.CONSOLE_SCREEN_BUFFER_INFO) callconv(windows.WINAPI) windows.BOOL;
    pub extern "kernel32" fn SetConsoleTextAttribute(h_console: windows.HANDLE, attrib: windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
};

pub const Fg = enum {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    LightGray,
    DarkGray,
    LightRed,
    LightGreen,
    LightYellow,
    LightBlue,
    LightMagenta,
    LightCyan,
    White,
};

/// Ignores color specifications
const PlainWriter = struct {
    writer: Writer,

    pub fn init(writer: Writer) PlainWriter {
        return PlainWriter{
            .writer = writer,
        };
    }

    pub fn writeSeq(self: *const PlainWriter, seq: anytype) !void {
        comptime var i: usize = 0;
        inline while (i < seq.len) : (i += 1) {
            const val = seq[i];
            switch (@TypeOf(val)) {
                Fg => {},
                else => {
                    try self.writer.writeAll(val);
                },
            }
        }
    }
};

/// Handles color using ANSI vTerm sequences
const AnsiWriter = struct {
    writer: Writer,

    pub fn init(writer: Writer) AnsiWriter {
        return AnsiWriter{
            .writer = writer,
        };
    }

    pub fn writeSeq(self: *const AnsiWriter, seq: anytype) !void {
        comptime var i: usize = 0;
        comptime var do_reset = false;
        inline while (i < seq.len) : (i += 1) {
            const val = seq[i];
            switch (@TypeOf(val)) {
                Fg => {
                    try self.writer.writeAll(AnsiWriter.fgSequence(val));
                    do_reset = true;
                },
                else => {
                    try self.writer.writeAll(val);
                },
            }
        }
        if (do_reset) {
            try self.writer.writeAll(ansi.Reset());
        }
    }

    fn fgSequence(fg: Fg) []const u8 {
        return switch (fg) {
            Fg.Black => ansi.Foreground(ansi.Black),
            Fg.Red => ansi.Foreground(ansi.Red),
            Fg.Green => ansi.Foreground(ansi.Green),
            Fg.Yellow => ansi.Foreground(ansi.Yellow),
            Fg.Blue => ansi.Foreground(ansi.Blue),
            Fg.Magenta => ansi.Foreground(ansi.Magenta),
            Fg.Cyan => ansi.Foreground(ansi.Cyan),
            Fg.LightGray => ansi.Foreground(ansi.LightGray),
            Fg.DarkGray => ansi.Foreground(ansi.DarkGray),
            Fg.LightRed => ansi.Foreground(ansi.LightRed),
            Fg.LightGreen => ansi.Foreground(ansi.LightGreen),
            Fg.LightYellow => ansi.Foreground(ansi.LightYellow),
            Fg.LightBlue => ansi.Foreground(ansi.LightBlue),
            Fg.LightMagenta => ansi.Foreground(ansi.LightMagenta),
            Fg.LightCyan => ansi.Foreground(ansi.LightCyan),
            Fg.White => ansi.Foreground(ansi.White),
        };
    }
};

/// Coloring text using Windows Console API
const WinConWriter = struct {
    writer: Writer,
    orig_attribs: windows.DWORD,

    pub fn init(writer: Writer) WinConWriter {
        var tmp: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        _ = wincon.GetConsoleScreenBufferInfo(writer.context.handle, &tmp);

        return WinConWriter{
            .writer = writer,
            .orig_attribs = tmp.wAttributes,
        };
    }

    pub fn writeSeq(self: *const WinConWriter, seq: anytype) !void {
        const handle = self.writer.context.handle;

        comptime var i: usize = 0;
        comptime var do_reset = false;
        inline while (i < seq.len) : (i += 1) {
            const val = seq[i];
            switch (@TypeOf(val)) {
                Fg => {
                    const foreground_mask = @as(windows.WORD, 0b1111);
                    const new_attrib = (self.orig_attribs & (~foreground_mask)) | WinConWriter.winConAttribValue(val);
                    _ = wincon.SetConsoleTextAttribute(handle, new_attrib);
                    do_reset = true;
                },
                else => try self.writer.writeAll(val),
            }
        }
        if (do_reset)
            _ = wincon.SetConsoleTextAttribute(handle, self.orig_attribs);
    }

    fn winConAttribValue(fg: Fg) windows.DWORD {
        const blue = windows.FOREGROUND_BLUE;
        const green = windows.FOREGROUND_GREEN;
        const red = windows.FOREGROUND_RED;
        const bright = windows.FOREGROUND_INTENSITY;

        return switch (fg) {
            Fg.Black => 0,
            Fg.Red => red,
            Fg.Green => green,
            Fg.Yellow => green | red,
            Fg.Blue => blue,
            Fg.Magenta => red | blue,
            Fg.Cyan => green | blue,
            Fg.LightGray => red | green | blue,
            Fg.DarkGray => bright,
            Fg.LightRed => red | bright,
            Fg.LightGreen => green | bright,
            Fg.LightYellow => red | green | bright,
            Fg.LightBlue => blue | bright,
            Fg.LightMagenta => red | blue | bright,
            Fg.LightCyan => blue | green | bright,
            Fg.White => red | green | blue | bright,
        };
    }
};

const WriterImpl = if (targeting_windows)
    union(enum) {
        Plain: PlainWriter,
        Ansi: AnsiWriter,
        WinCon: WinConWriter,
    }
else
    union(enum) {
        Plain: PlainWriter,
        Ansi: AnsiWriter,
    };

pub const OutputWriter = struct {
    impl: WriterImpl,

    pub fn writeSeq(self: *const OutputWriter, seq: anytype) !void {
        if (targeting_windows) {
            switch (self.impl) {
                WriterImpl.Plain => |w| try w.writeSeq(seq),
                WriterImpl.Ansi => |w| try w.writeSeq(seq),
                WriterImpl.WinCon => |w| try w.writeSeq(seq),
            }
        } else {
            switch (self.impl) {
                WriterImpl.Plain => |w| try w.writeSeq(seq),
                WriterImpl.Ansi => |w| try w.writeSeq(seq),
            }
        }
    }

    pub fn init(output: std.fs.File) OutputWriter {
        if (targeting_windows) {
            var mode: windows.DWORD = 0;
            if (wincon.GetConsoleMode(output.handle, &mode) != windows.FALSE) {
                const ENABLE_VIRTUAL_TERMINAL_PROCESSING: windows.DWORD = 0x0004;
                if (mode & ENABLE_VIRTUAL_TERMINAL_PROCESSING != 0) {
                    return OutputWriter{
                        .impl = WriterImpl{ .Ansi = AnsiWriter.init(output.writer()) },
                    };
                }
            } else {
                return OutputWriter{
                    .impl = WriterImpl{ .Plain = PlainWriter.init(output.writer()) },
                };
            }

            // Check if we run under ConEmu
            const wstr = std.unicode.utf8ToUtf16LeStringLiteral;
            if (std.os.getenvW(wstr("ConEmuANSI"))) |val| {
                if (std.mem.eql(u16, val, wstr("ON"))) {
                    return OutputWriter{
                        .impl = WriterImpl{ .Ansi = AnsiWriter.init(output.writer()) },
                    };
                }
            }

            return OutputWriter{
                .impl = WriterImpl{ .WinCon = WinConWriter.init(output.writer()) },
            };
        } else {
            // TODO: Examine isatty() & env(TERM) to make a decision
            return OutputWriter{
                .impl = WriterImpl{ .Ansi = AnsiWriter.init(output.writer()) },
            };
        }
    }
};
