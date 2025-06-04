//Neriya Horenczyk - 208729327
//Sagiv Maoz - 325570257
//the groop of Yair Goldshtein

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Token = @import("token.zig").Token;

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
        //if the file is not xml file then continue to the next iteration
        const first_point_location = mem.indexOf(u8, entry.name, ".") orelse entry.name.len;
        const clear_file_name = entry.name[0..first_point_location];
        if (!mem.endsWith(u8, entry.name, "T.xml")) continue;

        //create string with the final output file path
        const out_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.xml", .{ input_directory_path, clear_file_name[0 .. clear_file_name.len - 1] });
        defer allocator.free(out_file_path);

        //create the new output file or rewriting for it if it is existed before
        var out_file = try fs.cwd().createFile(out_file_path, .{ .truncate = true });
        defer out_file.close();

        //get a writer handle to the output file
        //var writer = out_file.writer();

        //getting the full path for this file
        const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ input_directory_path, entry.name });
        defer allocator.free(file_path);

        //opening the file for reading
        var jack_file = try fs.cwd().openFile(file_path, .{});
        defer jack_file.close();

        //translate the entire file into XML tree
        const content = try jack_file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        if (!mem.eql(u8, content, "")) {

            //convert the xml list into xml tree
            const x = try getTokens(allocator, content);

            for (x.items) |token| {
                std.debug.print("{s} {s}\n", .{ token.getLexeme(), token.getContent() });
            }
        }
    }
}

// helping method to convert the input xml file into list of tokens
fn getTokens(allocator: mem.Allocator, file_content: []u8) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(allocator);
    var i: usize = 0;

    while (i < file_content.len) {
        // find tag opening "<"
        if (file_content[i] != '<') {
            i += 1;
            continue;
        }

        // find the end of this tag ">"
        const tag_start = i + 1;
        const tag_end = std.mem.indexOfScalar(u8, file_content[tag_start..], '>') orelse break;
        const tag = file_content[tag_start .. tag_start + tag_end];
        i = tag_start + tag_end + 2;

        // if it is tokens tag then continue
        if (std.mem.eql(u8, tag, "tokens") or std.mem.eql(u8, tag, "/tokens")) {
            continue;
        }

        // find the closing tag
        const content_start = i;
        const content_end = std.mem.indexOfScalar(u8, file_content[content_start..], '<') orelse break;
        const content = file_content[content_start .. content_start + content_end - 1];
        i = content_start + content_end;

        // find the closing tag's content
        if (file_content[i] != '<' or file_content[i + 1] != '/') return error.InvalidXmlFormat;
        const closing_start = i + 2;
        const closing_end = std.mem.indexOfScalar(u8, file_content[closing_start..], '>') orelse break;
        const closing_tag = file_content[closing_start .. closing_start + closing_end];
        i = closing_start + closing_end + 2;

        // validate construction
        if (!std.mem.eql(u8, closing_tag, tag)) {
            return error.InvalidXmlFormat;
        }

        // add the new token to the token list
        const lexeme_copy = try allocator.dupe(u8, tag);
        const content_copy = try allocator.dupe(u8, content);
        try tokens.append(Token.init(lexeme_copy, content_copy));
    }

    return tokens;
}
