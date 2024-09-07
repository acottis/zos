const std = @import("std");

pub fn build(b: *std.Build) void {
    const UEFI_BIOS = "/usr/share/edk2/ovmf/OVMF_CODE.fd";

    const target = b.standardTargetOptions(.{ .default_target = .{
        .os_tag = .uefi,
        .cpu_arch = .x86_64,
    } });
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.exe_dir = "zig-out/EFI/BOOT/";
    b.installArtifact(exe);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-bios",
        UEFI_BIOS,
        "-drive",
        "file=fat:rw:zig-out,format=raw",
    });
    run_cmd.step.dependOn(b.default_step);

    const run_step = b.step("run", "Boot in qemu");
    run_step.dependOn(&run_cmd.step);
}
