const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    //getting the path of the files from the user
    args.next();
    const input_path = args.next() orelse return error.MissingPath;

    //get the last index of "/" or "\" if exists
    const slash_index = std.mem.lastIndexOf(u8, input_path, "/") orelse
        std.mem.lastIndexOf(u8, input_path, "\\") orelse 0;

    //extracting the last directory by slicing with the last index of "/" or "\"
    const out_file_name = input_path[slash_index + 1 ..];

    //open var for the directory
    var dir = try fs.cwd().openDir(input_path, .{ .iterate = true });
    defer dir.close();

    //create string with the final output file path
    const out_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.asm", .{ input_path, out_file_name });
    defer allocator.free(out_file_path);

    //create the output file in the directory
    var out_file = try fs.cwd().createFile(out_file_path, .{ .truncate = true });
    defer out_file.close();

    //create writer stream
    var writer = out_file.writer();

    //iterator for the directory itself!!
    var it = dir.iterate();

    var total_buy: f32 = 0;
    var total_sell: f32 = 0;

    //find each file with .vm ending and operate on it
    while (try it.next()) |entry| {
        //if this file does not ends with .vm then go on to the next iteration
        if (!mem.endsWith(u8, entry.name, ".vm")) continue;

        const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ input_path, entry.name });
        defer allocator.free(file_path);

        const file_base = entry.name[0 .. entry.name.len - 3]; // strip ".vm"
        try writer.print("// {s}\n", .{file_base});

        var vm_file = try fs.cwd().openFile(file_path, .{});
        defer vm_file.close();

        var reader = vm_file.reader();

        var line_buf: [256]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line_raw| {
            const line = std.mem.trim(u8, line_raw, " \t\r\n"); //remove at the start or the end
            if (line.len == 0) continue;

            //break the line by the delimiters " \t"
            var words_iter = mem.tokenizeAny(u8, line, " \t");
            const cmd = words_iter.next() orelse continue;
            const product = words_iter.next() orelse continue;
            const amount_str = words_iter.next() orelse continue;
            const price_str = words_iter.next() orelse continue;

            const amount = try std.fmt.parseInt(i32, amount_str, 10);
            const price = try std.fmt.parseFloat(f32, price_str);

            if (mem.eql(u8, cmd, "buy")) {
                try HandleBuy(writer, product, amount, price);
                total_buy += @as(f32, @floatFromInt(amount)) * price;
            } else if (mem.eql(u8, cmd, "sell")) {
                try HandleSell(writer, product, amount, price);
                total_sell += @as(f32, @floatFromInt(amount)) * price;
            }
        }
    }

    // Print to screen
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total BUY: {d:.2}\n", .{total_buy});
    try stdout.print("Total SELL: {d:.2}\n", .{total_sell});

    // Append to output file
    try writer.print("Total BUY: {d:.2}\n", .{total_buy});
    try writer.print("Total SELL: {d:.2}\n", .{total_sell});
}

fn HandleBuy(w: anytype, product: []const u8, amount: i32, price: f32) !void {
    try w.print("### BUY {s} ###\n", .{product});
    try w.print("{d:.2}\n", .{@as(f32, @floatFromInt(amount)) * price});
}

fn HandleSell(w: anytype, product: []const u8, amount: i32, price: f32) !void {
    try w.print("$$$ SELL {s} $$$\n", .{product});
    try w.print("{d:.2}\n", .{@as(f32, @floatFromInt(amount)) * price});
}
