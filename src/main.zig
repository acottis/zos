const std = @import("std");
const uefi = std.os.uefi;
const cpu = @import("cpu.zig");

const Writer = struct {
    inner: *uefi.protocol.SimpleTextOutput,

    fn init(simple_text_output: *uefi.protocol.SimpleTextOutput) @This() {
        return @This(){ .inner = simple_text_output };
    }
    fn print_comptime(self: @This(), comptime s: []const u8) void {
        _ = self.inner.outputString(std.unicode.utf8ToUtf16LeStringLiteral(s));
    }
    fn print(self: @This(), comptime fmt: []const u8, args: anytype) void {
        var buf = [_]u8{0} ** 2048;
        const str = std.fmt.bufPrint(&buf, fmt, args) catch {
            self.print_comptime("Failed to fmt print");
            return;
        };
        for (str) |char| {
            const char16 = [1:0]u16{char};
            _ = self.inner.outputString(&char16);
        }
    }

    fn clear(self: @This()) void {
        _ = self.inner.clearScreen();
    }
};

fn get_memory_map(mem_map_key: *usize) uefi.Status {
    const mem_map_desc_entries = 1000;
    var mem_map_size: usize = @sizeOf(uefi.tables.MemoryDescriptor) * mem_map_desc_entries;
    const mem_map_descs: ?[*]uefi.tables.MemoryDescriptor = &[_]uefi.tables.MemoryDescriptor{std.mem.zeroInit(uefi.tables.MemoryDescriptor, .{})} ** mem_map_desc_entries;
    var desc_size: usize = 0;
    var desc_version: u32 = 0;

    return uefi.system_table.boot_services.?.getMemoryMap(
        &mem_map_size,
        mem_map_descs,
        mem_map_key,
        &desc_size,
        &desc_version,
    );
}

pub fn main() uefi.Status {
    var res: uefi.Status = undefined;
    const writer = Writer.init(uefi.system_table.con_out.?);

    writer.clear();
    writer.print_comptime("Welcome to zos!\r\n");

    var graphics_output: *uefi.protocol.GraphicsOutput = undefined;
    res = uefi.system_table.boot_services.?.locateProtocol(&uefi.protocol.GraphicsOutput.guid, null, @ptrCast(&graphics_output));
    if (res != uefi.Status.Success) {
        writer.print("Failed to get graphics output {}\r\n", .{res});
    }
    const frame_buffer = graphics_output.mode.frame_buffer_base;
    writer.print("Frame Buffer Base: 0x{X}\r\n", .{frame_buffer});

    var mem_map_key: usize = 0;
    res = get_memory_map(&mem_map_key);
    if (res != uefi.Status.Success) {
        writer.print("Failed to read memory map {}\r\n", .{res});
    }

    res = uefi.system_table.boot_services.?.exitBootServices(uefi.handle, mem_map_key);
    if (res != uefi.Status.Success) {
        writer.print("Failed to exit boot services {}\r\n", .{res});
    }

    while (true) {
        cpu.halt();
    }

    return uefi.Status.Success;
}
