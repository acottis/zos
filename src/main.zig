const std = @import("std");
const uefi = std.os.uefi;

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

pub fn main() uefi.Status {
    const writer = Writer.init(uefi.system_table.con_out.?);

    writer.clear();
    writer.print_comptime("hi\r\n");

    const mmap_desc_entries = 1000;
    var mmap_size: usize = @sizeOf(uefi.tables.MemoryDescriptor) * mmap_desc_entries;
    const mmap_descs: ?[*]uefi.tables.MemoryDescriptor = &[_]uefi.tables.MemoryDescriptor{std.mem.zeroInit(uefi.tables.MemoryDescriptor, .{})} ** mmap_desc_entries;
    var map_key: usize = 0;
    var desc_size: usize = 0;
    var desc_version: u32 = 0;
    const res = uefi.system_table.boot_services.?.getMemoryMap(
        &mmap_size,
        mmap_descs,
        &map_key,
        &desc_size,
        &desc_version,
    );
    if (res != uefi.Status.Success) {
        writer.print("Failed to read memory map {}\r\n", .{res});
    }

    writer.print("{}", .{desc_version});

    while (true) {}

    return uefi.Status.Success;
}
