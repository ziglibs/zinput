const std = @import("std");
const ansi = @import("ansi.zig");
const testing = std.testing;

/// Caller must free memory.
pub fn askString(allocator: *std.mem.Allocator, prompt: []const u8, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut().writer();

    try out.writeAll(ansi.Foreground(ansi.Cyan) ++ "? " ++ ansi.Foreground(ansi.White));
    try out.writeAll(prompt);
    try out.writeAll(ansi.Foreground(ansi.DarkGray) ++ " > " ++ ansi.Reset());

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}

/// Caller must free memory. Max size is recommended to be a high value, like 512.
pub fn askDirPath(allocator: *std.mem.Allocator, prompt: []const u8, max_size: usize) ![]u8 {
    const out = std.io.getStdOut().writer();

    while (true) {
        const path = try askString(allocator, prompt, max_size);
        if (!std.fs.path.isAbsolute(path)) {
            try out.writeAll(ansi.Foreground(ansi.Red) ++ "Error: Invalid directory, please try again.\n\n" ++ ansi.Reset());
            allocator.free(path);
            continue;
        }

        var dir = std.fs.cwd().openDir(path, std.fs.Dir.OpenDirOptions{}) catch {
            try out.writeAll(ansi.Foreground(ansi.Red) ++ "Error: Invalid directory, please try again.\n\n" ++ ansi.Reset());
            allocator.free(path);
            continue;
        };

        dir.close();
        return path;
    }
}

pub fn askBool(prompt: []const u8) !bool {
    const in = std.io.getStdIn().reader();
    const out = std.io.getStdOut().writer();

    var buffer: [1]u8 = undefined;

    while (true) {
        try out.writeAll(ansi.Foreground(ansi.Cyan) ++ "? " ++ ansi.Foreground(ansi.White));
        try out.writeAll(prompt);
        try out.writeAll(ansi.Foreground(ansi.DarkGray) ++ " (y/n) > " ++ ansi.Reset());

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
    const out = std.io.getStdOut().writer();

    try out.writeAll(ansi.Foreground(ansi.Cyan) ++ "? " ++ ansi.Foreground(ansi.White));
    try out.writeAll(prompt);
    try out.writeAll(ansi.Foreground(ansi.DarkGray) ++ " (select one)" ++ ansi.Reset() ++ "\n\n");

    comptime var max_size: usize = 0;
    inline for (@typeInfo(options).Enum.fields) |option| {
        try out.writeAll("  - ");
        try out.writeAll(option.name);
        try out.writeAll("\n");

        if (option.name.len > max_size) max_size = option.name.len;
    }

    while (true) {
        var buffer: [max_size + 1]u8 = undefined;

        try out.writeAll(ansi.Foreground(ansi.DarkGray) ++ "\n>" ++ ansi.Reset() ++ " ");

        var result = (in.readUntilDelimiterOrEof(&buffer, '\n') catch {
            try in.skipUntilDelimiterOrEof('\n');
            try out.writeAll(ansi.Foreground(ansi.Red) ++ "Error: Invalid option, please try again.\n" ++ ansi.Reset());
            continue;
        }) orelse return error.EndOfStream;
        result = if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;

        inline for (@typeInfo(options).Enum.fields) |option|
            if (std.ascii.eqlIgnoreCase(u8, option.name, result))
                return @intToEnum(options, option.value);
        // return option.value;

        try out.writeAll(ansi.Foreground(ansi.Red) ++ "Error: Invalid option, please try again.\n" ++ ansi.Reset());
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
