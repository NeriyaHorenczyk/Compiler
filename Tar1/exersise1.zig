const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const Operation = enum {
    Eq,
    Gt,
    Not,
    Lt,
    And,
    Or,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Define the HashMap to map strings to function pointers
    var function_map = std.HashMap([]const u8, fn () void).init(allocator);
    defer function_map.deinit();

    try function_map.put("add", add);
    try function_map.put("sub", sub);
    try function_map.put("neg", neg);
    try function_map.put("eq", eq);
    try function_map.put("gt", gt);
    try function_map.put("not", not);
    try function_map.put("lt", lt);
    try function_map.put("and", andFn);
    try function_map.put("or", orFn);
    try function_map.put("push", push);
    try function_map.put("pop", pop);

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
    var countersArr: [6]i32 = [_]i32{0}; // Initialize all elements to 0

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line_raw| {
        const double_slash_index = mem.indexOf(u8, line_raw, "//") orelse line_raw.len;
        const trimmed_line = line_raw[0..double_slash_index];
        try writer.print("{s}\n", .{convertToHack(allocator, trimmed_line, &countersArr, function_map)});
    }
}

pub fn convertToHack(allocator: *std.mem.Allocator, command: []u8, countersArr: *[6]i32, function_map: *std.HashMap([]const u8, fn () void)) ![]u8 {
    var words_iter = mem.tokenizeAny(u8, command, " ");
    const result = function_map[words_iter.next()](allocator, &countersArr);
    return result;
}

pub fn add(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    return "@sp\nA=M-1\nD=M\nA=A-1\nM=D+M\n@sp\nM=M-1\n";
}

pub fn sub(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    return "@sp\nA=M-1\nD=M\nA=A-1\nM=M-D\n@sp\nM=M-1\n";
}

pub fn neg(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    return "@sp\nA=M-1\nM=-M";
}

pub fn eq(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\nA=A-1\nD=D-M\n@EQ", countersArr[Operation.Eq], "D;JEQ\n@sp\nA=M-1\nA=A-1\nM=0\n@ENDE", countersArr[Operation.Eq], "0;JMP\n(EQ", countersArr[Operation.Eq], ")\n@sp\nA=M-1\nA=A-1\nM=1\n(ENDE", countersArr[Operation.Eq], ")\n@sp\nM=M-1\n" });

    countersArr[Operation.Eq] = countersArr[Operation.Eq] + 1;
    return result;
}

pub fn gt(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\nA=A-1\nD=M-D\n@GT", countersArr[Operation.Gt], "D;JGT\n@sp\nA=M-1\nA=A-1\nM=0\n@ENDG", countersArr[Operation.Gt], "0;JMP\n(GT", countersArr[Operation.Gt], ")\n@sp\nA=M-1\nA=A-1\nM=1\n(ENDG", countersArr[Operation.Gt], ")\n@sp\nM=M-1\n" });

    countersArr[Operation.Gt] = countersArr[Operation.Gt] + 1;
    return result;
}

pub fn lt(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\nA=A-1\nD=D-M\n@LT", countersArr[Operation.Lt], "D;JGT\n@sp\nA=M-1\nA=A-1\nM=0\n@ENDL", countersArr[Operation.Lt], "0;JMP\n(LT", countersArr[Operation.Lt], ")\n@sp\nA=M-1\nA=A-1\nM=1\n(ENDL", countersArr[Operation.Lt], ")\n@sp\nM=M-1\n" });

    countersArr[Operation.Lt] = countersArr[Operation.Lt] + 1;
    return result;
}

pub fn andFn(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\n@FALSEA", countersArr[Operation.And], "\nD;JEQ\n@sp\nA=M-1\nA=A-1\nD=M\n@FALSEA", countersArr[Operation.And], "\nD;JEQ\n@sp\nA=M-1\nA=A-1\nM=1\n@ENDA", countersArr[Operation.And], "\n0;JMP\n(FALSEA", countersArr[Operation.And], ")\n@sp\nA=M-1\nA=A-1\nM=0\n(ENDA", countersArr[Operation.And], ")\n@sp\nM=M-1\n" });

    countersArr[Operation.And] = countersArr[Operation.And] + 1;
    return result;
}

pub fn orFn(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\n@TRUEO", countersArr[Operation.Or], "\nD;JGT\nD;JLT\n@sp\nA=M-1\nA=A-1\nD=M\n@TRUEO", countersArr[Operation.Or], "\nD;JGT\nD;JLT\n@sp\nA=M-1\nA=A-1\nM=0\n@ENDO", countersArr[Operation.Or], "\n0;JMP\n(TRUEO", countersArr[Operation.Or], ")\n@sp\nA=M-1\nA=A-1\nM=1\n(ENDO", countersArr[Operation.Or], ")\n@sp\nM=M-1\n" });

    countersArr[Operation.Or] = countersArr[Operation.Or] + 1;
    return result;
}

pub fn not(allocator: *std.mem.Allocator, countersArr: *[6]i32) ![]u8 {
    const result = std.fmt.allocPrint(allocator, "{s}{i32}{s}{i32}{s}{i32}{s}{i32}{s}", .{ "@sp\nA=M-1\nD=M\n@TRUEN", countersArr[Operation.Or], "\nD;JGT\nD;JLT\n@sp\nA=M-1\n@ENDN", countersArr[Operation.Or], "\n0;JMP\n(TRUEN", countersArr[Operation.Or], ")\n@sp\nA=M-1\nM=0\n(ENDN", countersArr[Operation.Or], ")\n" });

    countersArr[Operation.Or] = countersArr[Operation.Or] + 1;
    return result;
}
