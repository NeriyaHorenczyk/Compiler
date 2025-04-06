const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    //getting the path of the file from the user
    _ = args.next();
    const input_path = args.next() orelse return error.MissingPath;

    //ensure that the input file is in format .vm
    const file_ending = input_path[input_path.len - 3 ..];
    if (!mem.eql(u8, file_ending, ".vm")) {
        std.debug.print("no correct ending to the file:(", .{});
        return;
    }

    //get the last index of "/" or "\" if exists
    const last_slash_index = mem.lastIndexOf(u8, input_path, "/") orelse
        mem.lastIndexOf(u8, input_path, "\\") orelse 0;

    //get the path without the file
    const path_without_file = input_path[0..last_slash_index];

    //get the index of the second to last "/" or "\" if exists
    const second_slash_index = mem.lastIndexOf(u8, path_without_file, "/") orelse
        mem.lastIndexOf(u8, path_without_file, "\\") orelse 0;

    var out_file_name: []const u8 = undefined;
    var directory_path: []const u8 = undefined;

    //if there is no path given with the file name, exit
    if (last_slash_index == 0 and second_slash_index == 0) {
        std.debug.print("absolute path required :(", .{});
        return;
    } else {
        //extracting the last directory by slicing with the last index of "/" or "\"
        out_file_name = input_path[second_slash_index + 1 .. last_slash_index];
        directory_path = input_path[0..last_slash_index];
    }

    //open var for the directory
    var dir = try fs.cwd().openDir(directory_path, .{});
    defer dir.close();

    //create string with the final output file path
    const out_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.asm", .{ directory_path, out_file_name });
    defer allocator.free(out_file_path);

    //create the new output file or rewriting for it if it is existed before
    var out_file = try fs.cwd().createFile(out_file_path, .{ .truncate = true });
    defer out_file.close();

    //get a writer handle to the output file
    var writer = out_file.writer();

    //opening the input file
    var input_file = try fs.cwd().openFile(input_path, .{});
    defer input_file.close();
    //get a reader handle to the input file
    var reader = input_file.reader();

    //read the input file line by line and writing to the output file the line without notes
    var line_buf: [256]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line_raw| {
        const double_slash_index = mem.indexOf(u8, line_raw, "//") orelse line_raw.len;
        const trimmed_line = line_raw[0..double_slash_index];
        try writer.print("{s}\n", .{trimmed_line});
    }
}
