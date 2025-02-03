const std = @import("std");
const TranslateC = std.Build.Step.TranslateC;

pub fn build(b: *std.Build) !void {
    // Create sdk module, can be repeated for different headers (also see example header for requirements).
    const c_translate = try getPicoSdk(b, b.path("example.h"), .RP2040);
    // c_translate.addIncludeDir(...); // Can do if needed
    const pico_module = c_translate.createModule();

    // main build
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });
    const ziglib = b.addStaticLibrary(.{
        .name = "zigmain", // This is referenced by cmake (libzigmain.a) ensure they are the same
        .root_source_file = b.path("main.zig"),
        .target = try getTarget(b, .RP2040),
        .optimize = optimize,
    });
    // Add module for header
    ziglib.root_module.addImport("pico_sdk", pico_module);
    const zig_build = b.addInstallArtifact(ziglib, .{});

    // Cmake steps config and build
    const cmake_argv = [_][]const u8{ "cmake", "-B", b.install_path };
    const cmake_config = b.addSystemCommand(&cmake_argv);

    const make_argv = [_][]const u8{ "cmake", "--build", b.install_path, "--parallel" };
    const cmake_build = b.addSystemCommand(&make_argv);

    // build flow first to last...
    // C Translate is technically dependant on cmake config
    // but zls doesn't like that so we have a work around (see getPicoSdk)
    zig_build.step.dependOn(&c_translate.step);
    cmake_config.step.dependOn(&zig_build.step);
    cmake_build.step.dependOn(&cmake_config.step);
    b.getInstallStep().dependOn(&cmake_build.step);

    // Load flow - adds picotool load at the end
    // TODO: make cmake and this always match this file name or figure it out (find the uf2 file)...
    const uf2_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "zig_example.uf2" });
    const load_uf2_argv = [_][]const u8{ "picotool", "load", uf2_path };
    const load_uf2_cmd = b.addSystemCommand(&load_uf2_argv);
    const restart = [_][]const u8{ "picotool", "reboot" };
    const restart_cmd = b.addSystemCommand(&restart);
    const load_step = b.step("load", "Loads the uf2 with picotool");
    load_uf2_cmd.step.dependOn(b.getInstallStep());
    restart_cmd.step.dependOn(&load_uf2_cmd.step);
    load_step.dependOn(&restart_cmd.step);
}

const PicoPlatform = enum { RP2040 };

fn getTarget(b: *std.Build, platform: PicoPlatform) !std.Build.ResolvedTarget {
    switch (platform) {
        .RP2040 => {
            const targetq = std.zig.CrossTarget{
                .abi = .eabi,
                .cpu_arch = .thumb,
                .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m0plus },
                .os_tag = .freestanding,
            };
            return b.resolveTargetQuery(targetq);
        },
    }
}

fn getPicoSdk(b: *std.Build, root_source_file: std.Build.LazyPath, platform: PicoPlatform) !*TranslateC {
    // TODO: Not sure how to do this the "right" way.
    // Essentially this is needed so we can find the right headers: <assert.h> & <sys/cdefs.h>.
    // using the "correct" target seems to fail there in the translation of pico_sdk code.
    const targetq = std.zig.CrossTarget{
        .abi = .gnu,
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    };

    const c_translate = b.addTranslateC(.{
        .link_libc = true,
        .optimize = .ReleaseSmall,
        .target = b.resolveTargetQuery(targetq),
        .root_source_file = root_source_file,
    });
    // this should catch generated xxx.pio.h in most cases I think.  If there are subdirs in cmake they will need to be added manually.
    c_translate.addIncludeDir(b.install_path);

    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const pico_sdk_path = try std.process.getEnvVarOwned(allocator, "PICO_SDK_PATH");
    std.debug.print("SDK Found at: {s}\n", .{pico_sdk_path});

    var temp_path = try std.fs.path.join(allocator, &[_][]const u8{ b.install_path, "generated", "pico_base" });
    c_translate.addIncludeDir(temp_path);

    // Pico SRC folder
    const src_path = try std.fmt.allocPrint(allocator, "{s}/src", .{pico_sdk_path});
    var pico_includes = try findIncludeDirs(&arena, src_path, "include");
    for (pico_includes.items) |path| {
        c_translate.addIncludeDir(path);
    }
    defer pico_includes.deinit();

    // TinyUSB src folder
    const tiny_usb_path_src = try std.fmt.allocPrint(allocator, "{s}/lib/tinyusb/src", .{pico_sdk_path});
    c_translate.addIncludeDir(tiny_usb_path_src);
    var tiny_usb_includes = try findIncludeDirs(&arena, tiny_usb_path_src, "");
    for (tiny_usb_includes.items) |path| {
        c_translate.addIncludeDir(path);
    }
    defer tiny_usb_includes.deinit();
    // TinyUSB src folder
    const tiny_usb_path_hw = try std.fmt.allocPrint(allocator, "{s}/lib/tinyusb/hw", .{pico_sdk_path});
    c_translate.addIncludeDir(tiny_usb_path_hw);

    // TODO wireless stuff etc.

    // Works around some issue when importing uart.h
    c_translate.defineCMacroRaw("PICO_DEFAULT_UART_INSTANCE()=uart0");
    // Related to the libc issues above I think.
    c_translate.defineCMacroRaw("__unused=__attribute__((__unused__))");

    // not sure how important these are... see {pico_sdk}/src/rp2040.cmake
    switch (platform) {
        .RP2040 => {
            c_translate.defineCMacroRaw("PICO_RP2040=1");
            c_translate.defineCMacroRaw("PICO_RP2350=0");
            c_translate.defineCMacroRaw("PICO_RISCV=0");
            c_translate.defineCMacroRaw("PICO_ARM=1");
            c_translate.defineCMacroRaw("PICO_CMSIS_DEVICE=RP2040");
        },
        // TODO others.
    }

    // work around zls not being able to run the cmake commands...
    // TODO: Figure out why it can't
    // until then we create an empty config_autogen.h if one does not exist.
    // TODO: there must be an easier way to do this.
    temp_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "generated", "pico_base", "pico" });
    const temp_header_argv = [_][]const u8{ "mkdir", "-p", temp_path };
    const temp_gen_header = b.addSystemCommand(&temp_header_argv);
    b.allocator.free(temp_path);
    // write empty file
    temp_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "generated", "pico_base", "pico", "config_autogen.h" });
    const temp_header_argv2 = [_][]const u8{ "touch", temp_path };
    const temp_gen_header2 = b.addSystemCommand(&temp_header_argv2);
    b.allocator.free(temp_path);
    temp_gen_header2.step.dependOn(&temp_gen_header.step);
    temp_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "generated", "pico_base", "pico", "version.h" });
    const temp_header_argv3 = [_][]const u8{ "touch", temp_path };
    const temp_gen_header3 = b.addSystemCommand(&temp_header_argv3);
    b.allocator.free(temp_path);
    temp_gen_header3.step.dependOn(&temp_gen_header2.step);
    c_translate.step.dependOn(&temp_gen_header3.step);
    // ZLS workaround done...

    return c_translate;
}

fn findIncludeDirs(arena: *std.heap.ArenaAllocator, root: []const u8, folder_match: []const u8) !std.ArrayList([]const u8) {
    const allocator = arena.allocator();
    var dir_list = std.ArrayList([]const u8).init(allocator);
    var dir = try std.fs.cwd().openDir(root, .{ .no_follow = true, .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    defer dir.close();
    while (try walker.next()) |entry| {
        if (std.mem.startsWith(u8, entry.basename, folder_match) and entry.kind == .directory) {
            const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, entry.path });
            try dir_list.append(full_path);
        }
    }
    return dir_list;
}
