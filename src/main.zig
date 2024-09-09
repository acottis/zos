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

const Graphics = struct {
    buffer_base: u64,
    height: u32,
    width: u32,

    fn init(buffer_base: u64, height: u32, width: u32) @This() {
        return @This(){
            .buffer_base = buffer_base,
            .height = height,
            .width = width,
        };
    }
    fn draw_pixel(self: @This(), x: u32, y: u32) void {
        const offset: *u32 = @ptrFromInt(self.buffer_base + (y * self.width + x));
        offset.* = 0xFFFF;
    }
};

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
    const frame_height = graphics_output.mode.info.vertical_resolution;
    const frame_width = graphics_output.mode.info.horizontal_resolution;
    const graphics = Graphics.init(frame_buffer, frame_height, frame_width);
    writer.print("Frame Buffer Base: 0x{X}, Width: {}, Height: {}\r\n", .{
        frame_buffer,
        frame_width,
        frame_height,
    });

    var mem_map_key: usize = 0;
    res = get_memory_map(&mem_map_key);
    if (res != uefi.Status.Success) {
        writer.print("Failed to read memory map {}\r\n", .{res});
    }

    res = uefi.system_table.boot_services.?.exitBootServices(uefi.handle, mem_map_key);
    if (res != uefi.Status.Success) {
        writer.print("Failed to exit boot services {}\r\n", .{res});
    }

    graphics.draw_pixel(0, 0);

    while (true) {
        cpu.halt();
    }

    return uefi.Status.Success;
}
