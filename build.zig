const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sokol_dep = b.dependency("sokol", .{});

    const shader_step = b.step("shaders", "Compile shaders");
    const shader_cmd = b.addSystemCommand(&[_][]const u8{
        "./sokol-shdc",
        "-i",
        "sauce/shader.glsl",
        "-o",
        "sauce/shader.zig",
        "-l",
        "metal_macos",
        "-f",
        "sokol_zig",
    });
    shader_step.dependOn(&shader_cmd.step);

    const exe = b.addExecutable(.{
        .name = "zig-game",
        .root_source_file = b.path("sauce/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("sokol", sokol_dep.module("sokol"));

    exe.linkFramework("Metal");
    exe.linkFramework("Cocoa");
    exe.linkFramework("MetalKit");
    exe.linkFramework("QuartzCore");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&shader_cmd.step);
    run_step.dependOn(&run_cmd.step);

    const build_step = b.step("build-all", "Compile shaders and build the game");
    build_step.dependOn(&shader_cmd.step);
    build_step.dependOn(b.getInstallStep());
}
