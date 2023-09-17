const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardOptimizeOption(.{});
    // TODO: figure out how to add a static library in zig v0.11.0+
    // See also: https://devlog.hexops.com/2023/zig-0-11-breaking-build-changes/#creating-tests-libraries-and-executables

    // const lib = b.addStaticLibrary(.{ .name = "zinput", .main_pkg_path = "src/main.zig" });
    // _ = lib;

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
