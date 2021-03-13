const std = @import("std");
const testing = std.testing;
const writer = @import("writer.zig");
const Fg = writer.Fg;
const OutputWriter = writer.OutputWriter;

/// Caller must free memory.
pub fn askString(allocator: *std.mem.Allocator, prompt: []const u8, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().reader();
    const out = OutputWriter.init(std.io.getStdOut());

    try out.writeSeq(.{ Fg.Cyan, "? ", Fg.White, prompt });

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}

/// Caller must free memory. Max size is recommended to be a high value, like 512.
pub fn askDirPath(allocator: *std.mem.Allocator, prompt: []const u8, max_size: usize) ![]u8 {
    const out = OutputWriter.init(std.io.getStdOut());

    while (true) {
        const path = try askString(allocator, prompt, max_size);
        if (!std.fs.path.isAbsolute(path)) {
            try out.writeSeq(.{ Fg.Red, "Error: Invalid directory, please try again.\n\n" });
            allocator.free(path);
            continue;
        }

        var dir = std.fs.cwd().openDir(path, std.fs.Dir.OpenDirOptions{}) catch {
            try cw.writeSequence(.{ Fg.Red, "Error: Invalid directory, please try again.\n\n" });
            allocator.free(path);
            continue;
        };

        dir.close();
        return path;
    }
}

pub fn askBool(prompt: []const u8) !bool {
    const in = std.io.getStdIn().reader();
    const out = OutputWriter.init(std.io.getStdOut());

    var buffer: [1]u8 = undefined;

    while (true) {
        try out.writeSeq(.{ Fg.Cyan, "? ", Fg.White, prompt, Fg.DarkGray, " (y/n) > " });

        const read = in.read(&buffer) catch continue;
        try in.skipUntilDelimiterOrEof('\n');

        if (read == 0) return error.EndOfStream;

        switch (buffer[0]) {
            'y' => return true,
            'n' => return false,
            else => continue,
        }
    }
}

pub fn askSelectOne(prompt: []const u8, comptime options: type) !options {
    const in = std.io.getStdIn().reader();
    const out = OutputWriter.init(std.io.getStdOut());

    try out.writeSeq(.{ Fg.Cyan, "? ", Fg.White, prompt, Fg.DarkGray, " (select one)", "\n\n" });

    comptime var max_size: usize = 0;
    inline for (@typeInfo(options).Enum.fields) |option| {
        try out.writeSeq(.{ "  - ", option.name, "\n" });
        if (option.name.len > max_size) max_size = option.name.len;
    }

    while (true) {
        var buffer: [max_size + 1]u8 = undefined;

        try out.writeSeq(.{ Fg.DarkGray, "\n>", " " });

        var result = (in.readUntilDelimiterOrEof(&buffer, '\n') catch {
            try in.skipUntilDelimiterOrEof('\n');
            try out.writeSeq(.{ Fg.Red, "Error: Invalid option, please try again.\n" });
            continue;
        }) orelse return error.EndOfStream;
        result = if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;

        inline for (@typeInfo(options).Enum.fields) |option|
            if (std.ascii.eqlIgnoreCase(option.name, result))
                return @intToEnum(options, option.value);
        // return option.value;

        try out.writeSeq(.{ Fg.Red, "Error: Invalid option, please try again.\n" });
    }

    // return undefined;
}

test "basic input functionality" {
    std.debug.print("\n\n", .{});

    std.debug.print("Welcome to the ZLS configuration wizard! (insert mage emoji here)\n", .{});

    // const stdp = try askDirPath(testing.allocator, "What is your Zig lib path (path that contains the 'std' folder)?", 128);
    // const snippet = try askBool("Do you want to enable snippets?");
    // const style = try askBool("Do you want to enable style warnings?");
    const select = try askSelectOne("Which code editor do you use?", enum { VSCode, Sublime, Other });

    // defer testing.allocator.free(select);

    if (select == .VSCode) {}

    std.debug.print("\n\n", .{});
}
