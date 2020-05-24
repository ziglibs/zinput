const std = @import("std");
const testing = std.testing;

pub fn askString(allocator: *std.mem.Allocator, prompt: []const u8, max_size: usize) ![]u8 {
    const in = std.io.getStdIn().inStream();
    const out = std.io.getStdOut().outStream();

    _ = try out.write(prompt);
    _ = try out.write(" ");

    const result = try in.readUntilDelimiterAlloc(allocator, '\n', max_size);
    return if (std.mem.endsWith(u8, result, "\r")) result[0..(result.len - 1)] else result;
}

pub fn askStringUnsized(allocator: *std.mem.Allocator, prompt: []const u8) ![]u8 {
    return askString(allocator, prompt, @sizeOf(usize));
}

pub fn askBool(prompt: []const u8) !bool {
    const in = std.io.getStdIn().inStream();
    const out = std.io.getStdOut().outStream();

    var buffer: [1]u8 = undefined;

    while (true) {
        _ = try out.write(prompt);
        _ = try out.write(" (y/n) ");

        const read = in.read(&buffer) catch continue;
        try in.skipUntilDelimiterOrEof('\n');

        if (read == 0) return error.EndOFStream;

        switch (buffer[0]) {
            'y' => return true,
            'n' => return false,
            else => continue
        }
    }
}

test "basic input functionality" {
    std.debug.warn("\n\n", .{});

    std.debug.warn("Welcome to the ZLS configuration wizard! (insert mage emoji here)\n", .{});

    const stdp = try askStringUnsized(testing.allocator, "What is your Zig lib path (path that contains the 'std' folder)?");
    const snippet = try askBool("Do you want to enable snippets?");
    const style = try askBool("Do you want to enable style warnings?");

    defer testing.allocator.free(stdp);

    std.debug.warn("{} {} {}", .{stdp, snippet, style});

    // std.debug.warn("{} {} {}", .{stdp, snippet, style});

    std.debug.warn("\n\n", .{});
}
