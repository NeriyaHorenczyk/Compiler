//Neriya Horenczyk - 208729327
//Sagiv Maoz - 325570257
//the groop of Yair Goldshtein

const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const Operation = enum {
    Eq,
    Gt,
    Lt,
    Call,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    //getting the path of the file from the user
    _ = args.next() orelse return error.MissingFileName;
    const input_directory_path = args.next() orelse return error.MissingPath;

    //get the last index of "/" or "\" if exists to insolate the name of the directory
    const last_slash_index = mem.lastIndexOf(u8, input_directory_path, "/") orelse
        mem.lastIndexOf(u8, input_directory_path, "\\") orelse 0;

    var out_file_name: []const u8 = undefined;

    //extracting the last directory for the output file name
    out_file_name = input_directory_path[last_slash_index..input_directory_path.len];

    //open var for the directory
    var dir = try fs.cwd().openDir(input_directory_path, .{ .iterate = true });
    defer dir.close();

    //create string with the final output file path
    const out_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}.asm", .{ input_directory_path, out_file_name });
    defer allocator.free(out_file_path);

    //create the new output file or rewriting for it if it is existed before
    var out_file = try fs.cwd().createFile(out_file_path, .{ .truncate = true });
    defer out_file.close();

    //get a writer handle to the output file
    var writer = out_file.writer();

    var line_buf: [256]u8 = undefined;
    var countersArr: [4]i32 = [_]i32{ 0, 0, 0, 0 }; // Initialize all elements to 0, that is the counters array for the labels

    //check in the directory if there is a Sys.vm file, so it will generate bootstrap for him
    var is_sys: bool = false;
    var it = dir.iterate();
    while (try it.next()) |entry| {
        //if this file is Sys.vm
        if (std.mem.eql(u8, entry.name, "Sys.vm")) {
            is_sys = true;
            break;
        }
    }

    //if there is Sys.vm in the directory - generate bootstrap for it at the beginning of the output file
    if (is_sys) {
        const bootstrap = try generateBootstrapCode(allocator, &countersArr[@as(u8, @intFromEnum(Operation.Call))]);
        try writer.print("{s}\n", .{bootstrap});
        allocator.free(bootstrap);
    }

    it = dir.iterate();

    //going through each file in the directory
    while (try it.next()) |entry| {
        //if the file is not vm file then continue to the next iteration
        const first_point_location = mem.indexOf(u8, entry.name, ".") orelse entry.name.len;
        const clear_file_name = entry.name[0..first_point_location];
        if (!mem.endsWith(u8, entry.name, ".vm")) continue;

        //getting the full path for this file
        const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ input_directory_path, entry.name });
        defer allocator.free(file_path);

        //opening the file for reading
        var vm_file = try fs.cwd().openFile(file_path, .{});
        defer vm_file.close();

        //creating a reader handle
        var reader = vm_file.reader();

        //translate each line in the file into HACK commands
        while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line_raw| {
            //get rid of notes
            const double_slash_index = mem.indexOf(u8, line_raw, "//") orelse line_raw.len;
            const trimmed_line = line_raw[0..double_slash_index];
            //get rid of whitespaces at the end
            const cleaned_line = std.mem.trim(u8, trimmed_line, " \t\r\n");
            const cleaned = try allocator.dupe(u8, cleaned_line);
            if (!std.mem.eql(u8, cleaned, "")) {
                //print to the asm file note with the original vm command, for readability
                try writer.print("//{s}\n", .{cleaned_line});
                //convert the actual vm command to hack and writing it to the asm file
                const result = try convertToHack(allocator, cleaned, &countersArr, clear_file_name);
                try writer.print("{s}\n", .{result});
                allocator.free(result);
            }
        }
    }
}

pub fn convertToHack(allocator: std.mem.Allocator, command: []u8, countersArr: *[4]i32, file_name: []const u8) ![]u8 {
    var words_iter = mem.tokenizeAny(u8, command, " ");
    //get the command name
    const command_name = words_iter.next();
    //translating the command by the content of it
    if (command_name) |name| {
        if (std.mem.eql(u8, name, "add")) {
            if (words_iter.next() == null) {
                return generateAddCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "sub")) {
            if (words_iter.next() == null) {
                return generateSubCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "neg")) {
            if (words_iter.next() == null) {
                return generateNegCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "and")) {
            if (words_iter.next() == null) {
                return generateAndCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "or")) {
            if (words_iter.next() == null) {
                return generateOrCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "not")) {
            if (words_iter.next() == null) {
                return generateNotCode(allocator);
            }
        }
        if (std.mem.eql(u8, name, "eq")) {
            if (words_iter.next() == null) {
                return generateEqCode(allocator, &countersArr[@as(u8, @intFromEnum(Operation.Eq))]);
            }
        }
        if (std.mem.eql(u8, name, "gt")) {
            if (words_iter.next() == null) {
                return generateGtCode(allocator, &countersArr[@as(u8, @intFromEnum(Operation.Gt))]);
            }
        }
        if (std.mem.eql(u8, name, "lt")) {
            if (words_iter.next() == null) {
                return generateLtCode(allocator, &countersArr[@as(u8, @intFromEnum(Operation.Lt))]);
            }
        }

        if (std.mem.eql(u8, name, "push")) {
            const segment = words_iter.next();
            if (segment != null) {
                const index = words_iter.next();
                if (index != null) {
                    return generatePushCode(allocator, segment.?, index.?, file_name);
                }
            }
        }

        if (std.mem.eql(u8, name, "pop")) {
            const segment = words_iter.next();
            if (segment != null) {
                const index = words_iter.next();
                if (index != null) {
                    return generatePopCode(allocator, segment.?, index.?, file_name);
                }
            }
        }

        if (std.mem.eql(u8, name, "function")) {
            const func_name = words_iter.next();
            if (func_name != null) {
                const num_params = words_iter.next();
                if (num_params != null) {
                    return generateFunctionCode(allocator, func_name.?, num_params.?);
                }
            }
        }

        if (std.mem.eql(u8, name, "call")) {
            const func_name = words_iter.next();
            if (func_name != null) {
                const num_params = words_iter.next();
                if (num_params != null) {
                    return generateCallCode(allocator, func_name.?, num_params.?, &countersArr[@as(u8, @intFromEnum(Operation.Call))]);
                }
            }
        }

        if (std.mem.eql(u8, name, "return")) {
            if (words_iter.next() == null) {
                return generateReturnCode(allocator);
            }
        }

        if (std.mem.eql(u8, name, "label")) {
            const label_name = words_iter.next();
            if (label_name != null) {
                return generateLabelCode(allocator, file_name, label_name.?);
            }
        }

        if (std.mem.eql(u8, name, "goto")) {
            const label_name = words_iter.next();
            if (label_name != null) {
                return generateGotoCode(allocator, file_name, label_name.?);
            }
        }

        if (std.mem.eql(u8, name, "if-goto")) {
            const label_name = words_iter.next();
            if (label_name != null) {
                return generateIfGotoCode(allocator, file_name, label_name.?);
            }
        }

        return std.fmt.allocPrint(allocator, "//Error!", .{});
    }

    return std.fmt.allocPrint(allocator, "//Error!", .{});
}

pub fn generateAddCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\M=D+M
        \\@SP
        \\M=M-1
    , .{});
}

pub fn generateSubCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\M=M-D
        \\@SP
        \\M=M-1
    , .{});
}
pub fn generateNegCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\M=-M
    , .{});
}

pub fn generateEqCode(allocator: std.mem.Allocator, counter_ptr: *i32) ![]u8 {
    const i = counter_ptr.*;
    counter_ptr.* += 1;

    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\D=D-M
        \\@EQ_{d}
        \\D;JEQ
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=0
        \\@END_EQ_{d}
        \\0;JMP
        \\(EQ_{d})
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=-1
        \\(END_EQ_{d})
        \\@SP
        \\M=M-1
    , .{ i, i, i, i });
}

pub fn generateGtCode(allocator: std.mem.Allocator, counter_ptr: *i32) ![]u8 {
    const i = counter_ptr.*;
    counter_ptr.* += 1;

    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\D=M-D
        \\@GT_{d}
        \\D;JGT
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=0
        \\@END_GT_{d}
        \\0;JMP
        \\(GT_{d})
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=-1
        \\(END_GT_{d})
        \\@SP
        \\M=M-1
    , .{ i, i, i, i });
}

pub fn generateLtCode(allocator: std.mem.Allocator, counter_ptr: *i32) ![]u8 {
    const i = counter_ptr.*;
    counter_ptr.* += 1;

    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\D=D-M
        \\@LT_{d}
        \\D;JGT
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=0
        \\@END_LT_{d}
        \\0;JMP
        \\(LT_{d})
        \\@SP
        \\A=M-1
        \\A=A-1
        \\M=-1
        \\(END_LT_{d})
        \\@SP
        \\M=M-1
    , .{ i, i, i, i });
}

pub fn generateAndCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\M=D&M
        \\@SP
        \\M=M-1
    , .{});
}

pub fn generateOrCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\A=A-1
        \\M=D|M
        \\@SP
        \\M=M-1
    , .{});
}

pub fn generateNotCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\M=!M
    , .{});
}

pub fn generatePushCode(allocator: std.mem.Allocator, segment: []const u8, index: []const u8, file_name: []const u8) ![]u8 {
    //separate the cases of the push by the segment
    if (std.mem.eql(u8, segment, "local")) {
        return handleGroup1Push(allocator, "LCL", index);
    }
    if (std.mem.eql(u8, segment, "argument")) {
        return handleGroup1Push(allocator, "ARG", index);
    }
    if (std.mem.eql(u8, segment, "this")) {
        return handleGroup1Push(allocator, "THIS", index);
    }
    if (std.mem.eql(u8, segment, "that")) {
        return handleGroup1Push(allocator, "THAT", index);
    }
    if (std.mem.eql(u8, segment, "temp")) {
        return handleGroup2Push(allocator, index);
    }
    if (std.mem.eql(u8, segment, "static")) {
        return handleGroup3Push(allocator, index, file_name);
    }
    if (std.mem.eql(u8, segment, "pointer")) {
        return handleGroup4Push(allocator, index);
    }
    if (std.mem.eql(u8, segment, "constant")) {
        return handleGroup5Push(allocator, index);
    }
    return std.fmt.allocPrint(allocator, "//Error!", .{});
}

pub fn generatePopCode(allocator: std.mem.Allocator, segment: []const u8, index: []const u8, file_name: []const u8) ![]u8 {
    //separate the cases of the pop by the segment
    if (std.mem.eql(u8, segment, "local")) {
        return handleGroup1Pop(allocator, "LCL", index);
    }
    if (std.mem.eql(u8, segment, "argument")) {
        return handleGroup1Pop(allocator, "ARG", index);
    }
    if (std.mem.eql(u8, segment, "this")) {
        return handleGroup1Pop(allocator, "THIS", index);
    }
    if (std.mem.eql(u8, segment, "that")) {
        return handleGroup1Pop(allocator, "THAT", index);
    }
    if (std.mem.eql(u8, segment, "temp")) {
        return handleGroup2Pop(allocator, index);
    }
    if (std.mem.eql(u8, segment, "static")) {
        return handleGroup3Pop(allocator, index, file_name);
    }
    if (std.mem.eql(u8, segment, "pointer")) {
        return handleGroup4Pop(allocator, index);
    }
    return std.fmt.allocPrint(allocator, "//Error!", .{});
}

pub fn handleGroup1Push(allocator: std.mem.Allocator, segment: []const u8, index: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}
        \\D=A
        \\@{s}
        \\A=D+M
        \\D=M
        \\@SP
        \\A=M
        \\M=D
        \\@SP
        \\M=M+1
    , .{ index, segment });
}

pub fn handleGroup1Pop(allocator: std.mem.Allocator, segment: []const u8, index: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}
        \\D=A
        \\@{s}
        \\D=D+M
        \\@13
        \\M=D
        \\@SP
        \\A=M-1
        \\D=M
        \\@13
        \\A=M
        \\M=D
        \\@SP
        \\M=M-1
    , .{ index, segment });
}

pub fn handleGroup2Push(allocator: std.mem.Allocator, index: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}
        \\D=A
        \\@5
        \\A=D+A
        \\D=M
        \\@SP
        \\A=M
        \\M=D
        \\@SP
        \\M=M+1
    , .{index});
}

pub fn handleGroup2Pop(allocator: std.mem.Allocator, index: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}
        \\D=A
        \\@5
        \\D=D+A
        \\@13
        \\M=D
        \\@SP
        \\A=M-1
        \\D=M
        \\@13
        \\A=M
        \\M=D
        \\@SP
        \\M=M-1
    , .{index});
}

pub fn handleGroup3Push(allocator: std.mem.Allocator, index: []const u8, file_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}.{s}
        \\D=M
        \\@SP
        \\A=M
        \\M=D
        \\@SP
        \\M=M+1
    , .{ file_name, index });
}

pub fn handleGroup3Pop(allocator: std.mem.Allocator, index: []const u8, file_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\@{s}.{s}
        \\M=D
        \\@SP
        \\M=M-1
    , .{ file_name, index });
}

pub fn handleGroup4Push(allocator: std.mem.Allocator, index: []const u8) ![]u8 {
    var memory_index: i32 = 0;
    if (std.mem.eql(u8, index, "0")) {
        memory_index = 3;
    } else if (std.mem.eql(u8, index, "1")) {
        memory_index = 4;
    } else {
        return std.fmt.allocPrint(allocator, "//Error!", .{});
    }
    return std.fmt.allocPrint(allocator,
        \\@{d}
        \\D=M
        \\@SP
        \\A=M
        \\M=D
        \\@SP
        \\M=M+1
    , .{memory_index});
}

pub fn handleGroup4Pop(allocator: std.mem.Allocator, index: []const u8) ![]u8 {
    var memory_index: i32 = 0;
    if (std.mem.eql(u8, index, "0")) {
        memory_index = 3;
    } else if (std.mem.eql(u8, index, "1")) {
        memory_index = 4;
    } else {
        return std.fmt.allocPrint(allocator, "//Error!", .{});
    }
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\@{d}
        \\M=D
        \\@SP
        \\M=M-1
    , .{memory_index});
}

pub fn handleGroup5Push(allocator: std.mem.Allocator, index: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}
        \\D=A
        \\@SP
        \\A=M
        \\M=D
        \\@SP
        \\M=M+1
    , .{index});
}

pub fn generateBootstrapCode(allocator: std.mem.Allocator, counter_ptr: *i32) ![]u8 {
    //generate the code for "call Sys.init" command
    const call_sys = try generateCallCode(allocator, "Sys.init", "0", counter_ptr);
    defer allocator.free(call_sys);

    return std.fmt.allocPrint(allocator,
        \\@256
        \\D=A
        \\@SP
        \\M=D
        \\//call Sys.init 0
        \\{s}
    , .{call_sys});
}

pub fn generateFunctionCode(allocator: std.mem.Allocator, func_name: []const u8, num_params: []const u8) ![]u8 {
    //convert the number of local variables to actual number
    const num_params_number = try std.fmt.parseInt(usize, num_params, 10);

    //this is the variable that will contain the k times "push 0" translation
    var push_segment = try std.fmt.allocPrint(allocator, "//no locals", .{});
    defer allocator.free(push_segment);

    //if there is local variables so push them all
    if (num_params_number != 0) {
        //the translation to the push 0 when this push command is not the last push 0 command
        const push_zero_and_forward = "M=0\nA=A+1\n";
        //the translation to the push 0 when this push command is the last push 0 command
        const push_zero = "M=0";
        //the size of the string that will contain all the push commands together
        const total_len = (push_zero_and_forward.len * (num_params_number - 1)) + push_zero.len;
        allocator.free(push_segment);
        push_segment = try allocator.alloc(u8, total_len);
        //write the push commands
        for (0..num_params_number - 1) |i| {
            const dest_start = i * push_zero_and_forward.len;
            std.mem.copyForwards(u8, push_segment[dest_start..][0..push_zero_and_forward.len], push_zero_and_forward);
        }
        //write the last push command
        std.mem.copyForwards(u8, push_segment[(num_params_number - 1) * (push_zero_and_forward.len) ..], push_zero);
    }

    return std.fmt.allocPrint(allocator,
        \\({s})
        \\@SP
        \\A=M
        \\{s}
        \\@{s}
        \\D=A
        \\@SP
        \\M=M+D
    , .{ func_name, push_segment, num_params });
}

pub fn generateCallCode(allocator: std.mem.Allocator, func_name: []const u8, num_params: []const u8, counter_ptr: *i32) ![]u8 {
    const i = counter_ptr.*;
    counter_ptr.* += 1;

    return std.fmt.allocPrint(allocator,
        \\@RETURN_{s}_{d}
        \\D=A
        \\@SP
        \\A=M
        \\M=D
        \\@LCL
        \\D=M
        \\@SP
        \\A=M+1
        \\M=D
        \\D=A+1
        \\@SP
        \\M=D+1
        \\@ARG
        \\D=M
        \\@SP
        \\A=M-1
        \\M=D
        \\@THIS
        \\D=M
        \\@SP
        \\A=M
        \\M=D
        \\@THAT
        \\D=M
        \\@SP
        \\A=M+1
        \\M=D
        \\D=A+1
        \\@SP
        \\M=D
        \\@{s}
        \\D=A
        \\@5
        \\D=D+A
        \\@SP
        \\D=M-D
        \\@ARG
        \\M=D
        \\@SP
        \\D=M
        \\@LCL
        \\M=D
        \\@{s}
        \\0;JMP
        \\(RETURN_{s}_{d})
    , .{ func_name, i, num_params, func_name, func_name, i });
}

pub fn generateLabelCode(allocator: std.mem.Allocator, file_name: []const u8, label_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\({s}.{s})
    , .{ file_name, label_name });
}

pub fn generateGotoCode(allocator: std.mem.Allocator, file_name: []const u8, label_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@{s}.{s}
        \\0;JMP
    , .{ file_name, label_name });
}

pub fn generateIfGotoCode(allocator: std.mem.Allocator, file_name: []const u8, label_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@SP
        \\A=M-1
        \\D=M
        \\@SP
        \\M=M-1
        \\@{s}.{s}
        \\D;JNE
    , .{ file_name, label_name });
}

pub fn generateReturnCode(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\@LCL
        \\D=M
        \\@13
        \\M=D
        \\@5
        \\A=D-A
        \\D=M
        \\@14
        \\M=D
        \\@SP
        \\ AM=M-1
        \\D=M
        \\@ARG
        \\A=M
        \\M=D
        \\@ARG
        \\D=M+1
        \\@SP
        \\M=D
        \\@13
        \\AM=M-1
        \\D=M
        \\@THAT
        \\M=D
        \\@13
        \\AM=M-1
        \\D=M
        \\@THIS
        \\M=D
        \\@13
        \\AM=M-1
        \\D=M
        \\@ARG
        \\M=D
        \\@13
        \\AM=M-1
        \\D=M
        \\@LCL
        \\M=D
        \\@14
        \\A=M
        \\0;JMP
    , .{});
}
