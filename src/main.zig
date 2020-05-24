const std = @import("std");
const testing = std.testing;

pub const QueryType = union(enum) {
    text,
    boolean
};

pub const Query = struct {
    prompt: []const u8,
    max_size: ?usize = null,
    
    query_type: QueryType = QueryType.text
};

pub const Result = union(enum) {
    text: []u8,
    boolean: bool
};

pub const Asker = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    default_max_size: usize,

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self.initWithMaxSize(allocator, @sizeOf(usize));
    }

    pub fn initWithMaxSize(allocator: *std.mem.Allocator, max_size: usize) Self {
        return Self{
            .allocator = allocator,
            .default_max_size = max_size
        };
    }

    /// Caller must free memory with `asker.free(result)`.
    pub fn ask(self: Self, query: Query) !Result {

        const in_stream = std.io.getStdIn().inStream();
        const out_stream = std.io.getStdOut().outStream();

        _ = try out_stream.write(query.prompt);
        _ = try out_stream.write(" ");

        if (query.query_type == .boolean) {
            _ = try out_stream.write("(y/n) ");
        }

        var result = try in_stream.readUntilDelimiterAlloc(self.allocator, '\n', query.max_size orelse self.default_max_size);
        result = result[0..(result.len - 1)];

        switch (query.query_type) {
            .boolean => {
                defer self.allocator.free(result);
                if (std.mem.eql(u8, result, "y") or std.mem.eql(u8, result, "yes")) {
                    return Result{ .boolean = true };
                } else if (std.mem.eql(u8, result, "n") or std.mem.eql(u8, result, "no")) {
                    return Result{ .boolean = false };
                } else {
                    return self.ask(query);
                }
            },
            else => return Result{ .text = result }
        }
    }

    pub fn free(self: Self, result: Result) void {
        switch (result) {
            .text => |text| {
                self.allocator.free(text);
            },
            else => {}
        }
    }
};

test "basic input functionality" {
    std.debug.warn("\n\n", .{});

    std.debug.warn("Welcome to the ZLS configuration wizard! (insert mage emoji here)\n", .{});

    const std_query = Query{ .prompt = "What is your Zig lib path (path that contains the 'std' folder)?" };
    const snippet_query = Query{ .prompt = "Do you want to enable snippets?", .query_type = .boolean };
    const style_query = Query{ .prompt = "Do you want to enable style warnings?", .query_type = .boolean };

    var asker = Asker.init(testing.allocator);

    const stdp = try asker.ask(std_query);
    const snippet = try asker.ask(snippet_query);
    const style = try asker.ask(style_query);

    defer asker.free(stdp);
    defer asker.free(snippet);
    defer asker.free(style);

    std.debug.warn("{} {} {}", .{stdp, snippet, style});

    std.debug.warn("\n\n", .{});
}
