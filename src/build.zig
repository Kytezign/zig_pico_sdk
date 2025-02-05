const std = @import("std");
const pico = @import("pico_build.zig");
const TranslateC = std.Build.Step.TranslateC;

pub fn build(b: *std.Build) !void {

    // main build (must implement main function)
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });
    const ziglib = b.addStaticLibrary(.{
        .name = "zigmain", // This is referenced by cmake (libzigmain.a) ensure they are the same
        .root_source_file = b.path("main.zig"),
        .target = try pico.getTarget(b, .RP2040),
        .optimize = optimize,
    });
    // Create sdk c module, can be repeated for different headers (also see example header for requirements).
    const c_translate = try pico.getPicoSdk(b, b.path("example.h"), .RP2040);
    // c_translate.addIncludeDir(...); // Can do if needed
    ziglib.root_module.addImport("pico_sdk", c_translate.createModule());

    const zig_build = b.addInstallArtifact(ziglib, .{});

    const cmake_config = pico.getCmakeConfig(b);
    const pio_build = try pico.getPIOBuild(b, "zig_example", "async_spi.pio");
    const cmake_build = pico.getCmakeBuild(b);

    // Cmake config comes first
    pio_build.step.dependOn(&cmake_config.step);
    // Then the PIO header generation step.
    // Keep in mind if the header is generated in a subdirectory it will need to be refrenced manually in the c translate.
    c_translate.step.dependOn(&pio_build.step);
    // Translate next followed by zig build (zig_build implicitly depends on c translate as part addImport call)
    cmake_build.step.dependOn(&zig_build.step);
    // Finally we do the full cmake build.
    b.getInstallStep().dependOn(&cmake_build.step);

    // Load step - adds picotool load at the end.
    // Picotool must be callable in the path.
    const uf2_path = b.getInstallPath(.prefix, "zig_example.uf2");
    pico.addLoadStep(b, uf2_path);
}
