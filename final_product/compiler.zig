const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next() orelse return error.MissingFileName;
    const input_directory_path = args.next() orelse return error.MissingPath;

    // run all the levels of the compiler
    try runExe("./jack_to_Txml.exe", input_directory_path, allocator);
    try runExe("./Txml_to_xml.exe", input_directory_path, allocator);
    try runExe("./Txml_to_vm.exe", input_directory_path, allocator);
    try runExe("./vm_to_asm.exe", input_directory_path, allocator);

    //open var for the directory
    var dir = try fs.cwd().openDir(input_directory_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();

    //going through each file in the directory
    while (try it.next()) |entry| {
        if (!mem.endsWith(u8, entry.name, ".xml")) continue;

        try dir.deleteFile(entry.name);
    }
}

fn runExe(exe: []const u8, input: []const u8, allocator: std.mem.Allocator) !void {
    _ = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ exe, input },
        .cwd = null,
        .max_output_bytes = 1024 * 100,
    });
}
