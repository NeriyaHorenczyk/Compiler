//Neriya Horenczyk - 208729327
//Sagiv Maoz - 325570257
//the groop of Yair Goldshtein

const states = @import("states.zig");
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Writer = std.io.Writer(std.fs.File, std.fs.File.WriteError, std.fs.File.write);

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    //getting the path of the directory from the user
    _ = args.next() orelse return error.MissingFileName;
    const input_directory_path = args.next() orelse return error.MissingPath;

    //open var for the directory
    var dir = try fs.cwd().openDir(input_directory_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();

    //going through each file in the directory
    while (try it.next()) |entry| {
        //if the file is not vm file then continue to the next iteration
        const first_point_location = mem.indexOf(u8, entry.name, ".") orelse entry.name.len;
        const clear_file_name = entry.name[0..first_point_location];
        if (!mem.endsWith(u8, entry.name, ".jack")) continue;

        //create string with the final output file path
        const out_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}T.xml", .{ input_directory_path, clear_file_name });
        defer allocator.free(out_file_path);

        //create the new output file or rewriting for it if it is existed before
        var out_file = try fs.cwd().createFile(out_file_path, .{ .truncate = true });
        defer out_file.close();

        //get a writer handle to the output file
        var writer = out_file.writer();

        //getting the full path for this file
        const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ input_directory_path, entry.name });
        defer allocator.free(file_path);

        //opening the file for reading
        var jack_file = try fs.cwd().openFile(file_path, .{});
        defer jack_file.close();

        try writer.print("<tokens>\n", .{});

        //translate the entire file into XML tokens
        const contents = try jack_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(contents);

        if (!std.mem.eql(u8, contents, "")) {
            //convert the actual jack line to xml and writing it to the xml file
            try writeTokens(allocator, contents, writer);
        }

        try writer.print("</tokens>", .{});
    }
}

pub fn writeTokens(allocator: std.mem.Allocator, file_content: []u8, writer: Writer) !void {
    var current_character: u8 = 0;
    while (current_character != file_content.len) {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        states.q0(file_content, &current_character, &buffer, writer);
    }
}
