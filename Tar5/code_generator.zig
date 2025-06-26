const std = @import("std");
const Token = @import("token.zig").Token;
const records = @import("symbol_table_records.zig");
const FunctionMap = std.StringHashMap(records.FunctionRecord);
const ClassMap = std.StringHashMap(records.ClassRecord);
const tokens = @import("tokens.zig");

// helping function to return the current token
fn peek(tokens_list: std.ArrayList(Token), index: usize) anyerror!Token {
    return tokens_list.items[(index)];
}

// helping function to write vm code to the output file
fn writeCode(writer: anytype, code: []u8) anyerror!void {
    try writer.print("{s}", .{code});
}

// the function that proceeds to the next token, unlike the match function, here we dont need to
// match the token, beacause we already know what token we are looking for :)
fn proceed(current: *usize) anyerror!void {
    current.* += 1;
    return;
}

// helping function to put some record inside the class symbol table
fn insert_into_class_symbol_table(allocator: std.mem.Allocator, class_table: *ClassMap, var_type: []const u8, is_static: bool, index: *usize) anyerror!void {
    const record_ptr = allocator.create(records.ClassRecord) catch unreachable;
    record_ptr.* = records.ClassRecord.init(var_type, is_static, index.*);
    class_table.put(var_type, record_ptr.*) catch unreachable;

    index.* += 1;
}

// helping function to extract the segment from some record in the symbol tables
fn extract_segment_from_symbol_tables(class_table: *ClassMap, function_table: *FunctionMap, var_name: []const u8) anyerror!?[]const u8 {
    if (function_table.get(var_name)) |function_record| {
        return function_record.getSegment();
    } else if (class_table.get(var_name)) |class_record| {
        return class_record.getSegment();
    }

    return null;
}

// helping function to extract the index from some record in the symbol tables
fn extract_index_from_symbol_tables(class_table: *ClassMap, function_table: *FunctionMap, var_name: []const u8) anyerror!?usize {
    if (function_table.get(var_name)) |function_record| {
        return function_record.index;
    } else if (class_table.get(var_name)) |class_record| {
        return class_record.index;
    }
    return null;
}

//--------------------------------------------------------
// the code writer functions:
//--------------------------------------------------------
pub fn _class(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, static_counter: *usize, field_counter: *usize, label_counter: *usize) anyerror!void {
    std.debug.print("class\n", .{});

    // ignore 'class'
    try proceed(current);

    // go over the class name
    try _className(current);

    // ignore '{'
    try proceed(current);

    // while we have class variables, we will handle them
    while ((try peek(tokens_list, (current.*))).equals(tokens.static_kw) or (try peek(tokens_list, (current.*))).equals(tokens.field_kw)) {
        try _classVarDec(allocator, tokens_list, current, class_table, static_counter, field_counter);
    }

    // while we have subroutine declarations, we will handle them
    while ((try peek(tokens_list, (current.*))).equals(tokens.constructor_kw) or (try peek(tokens_list, (current.*))).equals(tokens.method_kw) or (try peek(tokens_list, (current.*))).equals(tokens.function_kw)) {
        try _subroutineDec(allocator, writer, tokens_list, current, class_table, label_counter);
    }

    // ignore '}'
    try proceed(current);

    return;
}

fn _ifStatement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap, label_counter: *usize) anyerror!void {
    std.debug.print("if\n", .{});

    const current_label = label_counter.*;
    label_counter.* += 1;

    //ignore the 'if' keyword
    try proceed(current);

    //ignore the '('
    try proceed(current);

    try _expression(allocator, writer, tokens_list, current, class_table, function_table);

    var code = try std.fmt.allocPrint(allocator, "not\n if-goto L{d}\n", .{current_label});
    try writeCode(writer, code);
    allocator.free(code);

    //ignore the ')'
    try proceed(current);

    // ignore the '{'
    try proceed(current);

    try _statements(allocator, writer, tokens_list, current, class_table, function_table, label_counter);

    // ignore the '}'
    try proceed(current);

    if ((try peek(tokens_list, (current.*))).equals(tokens.else_kw)) {
        const next_label = label_counter.*;
        label_counter.* += 1;

        code = try std.fmt.allocPrint(allocator, "goto L{d}\nlabel{d}\n", .{ next_label, current_label });
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the 'else' keyword
        try proceed(current);

        // ignore the '{'
        try proceed(current);

        try _statements(allocator, writer, tokens_list, current, class_table, function_table, label_counter);

        code = try std.fmt.allocPrint(allocator, "label L{d}\n", .{next_label});
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the '}'
        try proceed(current);
    } else {
        code = try std.fmt.allocPrint(allocator, "label L{d}\n", .{current_label});
        try writeCode(writer, code);
        allocator.free(code);
    }
}

fn _letStatement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("let\n", .{});

    //ignore the 'let' keyword
    try proceed(current);

    const var_name = try _varName(tokens_list, current);

    const var_index = try extract_index_from_symbol_tables(class_table, function_table, var_name) orelse {
        std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
        std.process.exit(0);
    };
    const var_segment = try extract_segment_from_symbol_tables(class_table, function_table, var_name) orelse {
        std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
        std.process.exit(0);
    };

    // check if the variable is an array
    if ((try peek(tokens_list, (current.*))).equals(tokens.lbracket)) {
        var code = try std.fmt.allocPrint(allocator, "push {s} {d}\n", .{ var_segment, var_index });
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the '['
        try proceed(current);

        try _expression(allocator, writer, tokens_list, current, class_table, function_table);

        code = try std.fmt.allocPrint(allocator, "add\n", .{});
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the ']'
        try proceed(current);

        // ignore the '='
        try proceed(current);

        try _expression(allocator, writer, tokens_list, current, class_table, function_table);

        code = try std.fmt.allocPrint(allocator, "pop temp 0\npop pointer 1\npush temp 0\npop that 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the ';'
        try proceed(current);
    } else { // if it is not an array, we will just assign the value to the variable
        // ignore the '='
        try proceed(current);

        try _expression(allocator, writer, tokens_list, current, class_table, function_table);

        const code = try std.fmt.allocPrint(allocator, "push {s} {d}\n", .{ var_segment, var_index });
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the ';'
        try proceed(current);
    }
}

fn _whileStatement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap, label_counter: *usize) anyerror!void {
    std.debug.print("while\n", .{});

    const current_label = label_counter.*;
    const next_label = label_counter.* + 1;
    label_counter.* += 2;

    // ignore the 'while' keyword
    try proceed(current);

    var code = try std.fmt.allocPrint(allocator, "label L{d}\n", .{current_label});
    try writeCode(writer, code);
    allocator.free(code);

    // ignore the '('
    try proceed(current);

    try _expression(allocator, writer, tokens_list, current, class_table, function_table);

    code = try std.fmt.allocPrint(allocator, "not\nif-goto L{d}\n", .{next_label});
    try writeCode(writer, code);
    allocator.free(code);

    //ignore the ')'
    try proceed(current);

    // ignore the '{'
    try proceed(current);

    try _statements(allocator, writer, tokens_list, current, class_table, function_table, label_counter);

    code = try std.fmt.allocPrint(allocator, "goto L{d}\nlabel L{d}\n", .{ current_label, next_label });
    try writeCode(writer, code);
    allocator.free(code);

    // ignore the '}'
    try proceed(current);
}

fn _statement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap, label_counter: *usize) anyerror!void {
    std.debug.print("statement\n", .{});

    if ((try peek(tokens_list, (current.*))).equals(tokens.if_kw)) {
        try _ifStatement(allocator, writer, tokens_list, current, class_table, function_table, label_counter);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.let_kw)) {
            try _letStatement(allocator, writer, tokens_list, current, class_table, function_table);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.while_kw)) {
                try _whileStatement(allocator, writer, tokens_list, current, class_table, function_table, label_counter);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.do_kw)) {
                    try _doStatement(allocator, writer, tokens_list, current, class_table, function_table);
                } else {
                    if ((try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
                        try _returnStatement(allocator, writer, tokens_list, current, class_table, function_table);
                    }
                }
            }
        }
    }
}

fn _statements(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap, label_counter: *usize) anyerror!void {
    std.debug.print("statements\n", .{});

    while ((try peek(tokens_list, (current.*))).equals(tokens.if_kw) or (try peek(tokens_list, (current.*))).equals(tokens.let_kw) or (try peek(tokens_list, (current.*))).equals(tokens.while_kw) or (try peek(tokens_list, (current.*))).equals(tokens.do_kw) or (try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
        try _statement(allocator, writer, tokens_list, current, class_table, function_table, label_counter);
    }
}

fn _subroutineCall(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("subroutineCall\n", .{});

    if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
        const sub_routine_name = try _subroutineName(tokens_list, current);

        var code = try std.fmt.allocPrint(allocator, "push pointer 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the '('
        try proceed(current);

        var num_arguments = try _expressionList(allocator, writer, tokens_list, current, class_table, function_table);

        num_arguments += 1; // we need to add the 'this' pointer

        code = try std.fmt.allocPrint(allocator, "call {s} {d}\n", .{ sub_routine_name, num_arguments });
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the ')'
        try proceed(current);
    } else {
        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
            const var_name: []const u8 = try _varName(tokens_list, current);

            var num_arguments: usize = 0;

            const var_index = try extract_index_from_symbol_tables(class_table, function_table, var_name);
            const var_segment = try extract_segment_from_symbol_tables(class_table, function_table, var_name);

            if (var_index != null and var_segment != null) {
                const code = try std.fmt.allocPrint(allocator, "push {s} {d}\n", .{ var_segment.?, var_index.? });
                try writeCode(writer, code);
                allocator.free(code);

                num_arguments += 1; // we need to add the 'this' pointer
            }

            // ignore the '.'
            try proceed(current);

            const sub_routine_name = try _subroutineName(tokens_list, current);

            // ignore the '('
            try proceed(current);

            num_arguments += try _expressionList(allocator, writer, tokens_list, current, class_table, function_table);

            const code = try std.fmt.allocPrint(allocator, "call {s}.{s} {d}\n", .{ var_name, sub_routine_name, num_arguments });
            try writeCode(writer, code);
            allocator.free(code);

            // ignore the ')'
            try proceed(current);
        }
    }
}

fn _term(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("term\n", .{});

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant)) {
        const code = try std.fmt.allocPrint(allocator, "push constant {s}\n", .{(try peek(tokens_list, (current.*))).content});
        try writeCode(writer, code);
        allocator.free(code);

        // ignore the integer constant
        try proceed(current);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.stringConstant)) {
            for ((try peek(tokens_list, (current.*))).content) |ch| {
                const code = try std.fmt.allocPrint(allocator, "push constant {d}\ncall String.appendChar 2\n", .{ch});
                try writeCode(writer, code);
                allocator.free(code);
            }
            //ignore the string constant
            try proceed(current);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw)) {
                try _keywordConstant(allocator, writer, tokens_list, current);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.lparen)) {
                    // ignore the '('
                    try proceed(current);

                    try _expression(allocator, writer, tokens_list, current, class_table, function_table);

                    // ignore the ')'
                    try proceed(current);
                } else {
                    if (((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) or ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier))) {
                        try _subroutineCall(allocator, writer, tokens_list, current, class_table, function_table);
                    } else {
                        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lbracket) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
                            const var_name = try _varName(tokens_list, current);

                            const var_index = try extract_index_from_symbol_tables(class_table, function_table, var_name) orelse {
                                std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
                                std.process.exit(0);
                            };
                            const var_segment = try extract_segment_from_symbol_tables(class_table, function_table, var_name) orelse {
                                std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
                                std.process.exit(0);
                            };

                            var code = try std.fmt.allocPrint(allocator, "push {s} {d}\n", .{ var_segment, var_index });
                            try writeCode(writer, code);
                            allocator.free(code);

                            // ignore the '['
                            try proceed(current);

                            try _expression(allocator, writer, tokens_list, current, class_table, function_table);

                            code = try std.fmt.allocPrint(allocator, "add\npop pointer 1\npush that 0\n", .{});
                            try writeCode(writer, code);
                            allocator.free(code);

                            // ignore the ']'
                            try proceed(current);
                        } else {
                            if ((try peek(tokens_list, (current.*))).equals(tokens.tilde) or (try peek(tokens_list, (current.*))).equals(tokens.minus)) {
                                const is_minus = try _unaryOp(tokens_list, current);

                                try _term(allocator, writer, tokens_list, current, class_table, function_table);

                                if (is_minus) {
                                    const code = try std.fmt.allocPrint(allocator, "neg\n", .{});
                                    try writeCode(writer, code);
                                    allocator.free(code);
                                } else {
                                    const code = try std.fmt.allocPrint(allocator, "not\n", .{});
                                    try writeCode(writer, code);
                                    allocator.free(code);
                                }
                            } else {
                                if (((try peek(tokens_list, (current.*))).equals(tokens.identifier)) and ((try peek(tokens_list, (current.*) + 1)).equals(tokens.rparen) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.rbracket) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.semicolon) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.comma) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.plus) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.minus) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.slash) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.star) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.pipe) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.amp) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.lt) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.gt) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.equal))) {
                                    const var_name = try _varName(tokens_list, current);

                                    const var_index = try extract_index_from_symbol_tables(class_table, function_table, var_name) orelse {
                                        std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
                                        std.process.exit(0);
                                    };
                                    const var_segment = try extract_segment_from_symbol_tables(class_table, function_table, var_name) orelse {
                                        std.debug.print("variable \"{s}\" not found in class or function", .{var_name});
                                        std.process.exit(0);
                                    };

                                    const code = try std.fmt.allocPrint(allocator, "push {s} {d}\n", .{ var_segment, var_index });
                                    try writeCode(writer, code);
                                    allocator.free(code);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fn _expression(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("expression\n", .{});

    try _term(allocator, writer, tokens_list, current, class_table, function_table);

    var current_token = (try peek(tokens_list, (current.*)));

    while (current_token.equals(tokens.plus) or
        current_token.equals(tokens.minus) or
        current_token.equals(tokens.star) or
        current_token.equals(tokens.slash) or
        current_token.equals(tokens.amp) or
        current_token.equals(tokens.pipe) or
        current_token.equals(tokens.lt) or
        current_token.equals(tokens.gt) or
        current_token.equals(tokens.equal))
    {
        try _op(allocator, writer, tokens_list, current);

        try _term(allocator, writer, tokens_list, current, class_table, function_table);

        current_token = (try peek(tokens_list, (current.*)));
    }
}

fn _op(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    std.debug.print("op\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.plus)) {
        // ignore the '+'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "add\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.minus)) {
        // ignore the '-'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "sub\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.star)) {
        // ignore the '*'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "call Math.multiply 2\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.slash)) {
        // ignore the '/'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "call Math.divide 2\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.amp)) {
        // ignore the '&'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "and\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.pipe)) {
        // ignore the '|'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "or\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.gt)) {
        // ignore the '>'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "gt\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.lt)) {
        // ignore the '<'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "lt\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.equal)) {
        // ignore the '='
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "eq\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    }
}

fn _doStatement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("do\n", .{});

    // ignore the 'do' keyword
    try proceed(current);

    try _subroutineCall(allocator, writer, tokens_list, current, class_table, function_table);

    // ignore the ';'
    try proceed(current);
}

fn _returnStatement(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!void {
    std.debug.print("return\n", .{});

    // ignore the 'return' keyword
    try proceed(current);

    if (!(try peek(tokens_list, (current.*))).equals(tokens.semicolon)) {
        try _expression(allocator, writer, tokens_list, current, class_table, function_table);
    }

    const code = try std.fmt.allocPrint(allocator, "return\n", .{});
    try writeCode(writer, code);
    allocator.free(code);

    // ignore the ';'
    try proceed(current);
}

fn _expressionList(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap) anyerror!usize {
    std.debug.print("expression list\n", .{});

    var num_expressions: usize = 0;

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant) or (try peek(tokens_list, (current.*))).equals(tokens.stringConstant) or (try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw) or (try peek(tokens_list, (current.*))).equals(tokens.identifier) or (try peek(tokens_list, (current.*))).equals(tokens.lparen) or (try peek(tokens_list, (current.*))).equals(tokens.minus) or (try peek(tokens_list, (current.*))).equals(tokens.tilde)) {
        try _expression(allocator, writer, tokens_list, current, class_table, function_table);

        num_expressions += 1;

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            // ignore the ','
            try proceed(current);

            try _expression(allocator, writer, tokens_list, current, class_table, function_table);

            num_expressions += 1;
        }
    }

    return num_expressions;
}

fn _keywordConstant(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    std.debug.print("keyword constant\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.true_kw)) {
        // ignore the 'true'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "push constant -1\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.false_kw)) {
        // ignore the 'false'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "push constant 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.null_kw)) {
        // ignore the 'null'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "push constant 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    } else if (current_token.equals(tokens.this_kw)) {
        // ignore the 'this'
        try proceed(current);
        const code = try std.fmt.allocPrint(allocator, "push pointer 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
    }
}

fn _unaryOp(tokens_list: std.ArrayList(Token), current: *usize) anyerror!bool {
    std.debug.print("unary op\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.tilde)) {
        // ignore the '~'
        try proceed(current);
        return false;
    }
    // if it is a minus, we will return true, so we can negate the value later
    // ignore the '-'
    try proceed(current);
    return true;
}

fn _className(current: *usize) anyerror!void {
    std.debug.print("class name\n", .{});
    try proceed(current);
}

fn _subroutineName(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]const u8 {
    std.debug.print("subroutine name\n", .{});

    const result = (try peek(tokens_list, (current.*))).content;

    try proceed(current);

    return result;
}

fn _varName(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]const u8 {
    std.debug.print("var name\n", .{});

    // get the variable name
    const result = (try peek(tokens_list, (current.*))).content;

    // get over the variable name
    try proceed(current);

    // return the variable name
    return result;
}

fn _classVarDec(allocator: std.mem.Allocator, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, static_counter: *usize, field_counter: *usize) anyerror!void {
    std.debug.print("class variable declaration\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    // check if the current token is 'static' or 'field'
    var is_static: bool = false;

    // if it is 'static' or 'field', we will use it to determine the variable type
    if (current_token.equals(tokens.static_kw)) {
        is_static = true;
    }

    // ignore 'static' or 'field'
    try proceed(current);

    const var_type: []const u8 = try _type(tokens_list, current);

    var var_name: []const u8 = try _varName(tokens_list, current);

    // add the class variable to the class symbol table

    try insert_into_class_symbol_table(allocator, class_table, var_type, is_static, if (is_static) static_counter else field_counter);

    while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
        // ignore ','
        try proceed(current);

        var_name = try _varName(tokens_list, current);

        // add the class variable to the class symbol table
        try insert_into_class_symbol_table(allocator, class_table, var_type, is_static, if (is_static) static_counter else field_counter);
    }

    // ignore ';'
    try proceed(current);
}

fn _type(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]const u8 {
    std.debug.print("type\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    try proceed(current);
    return current_token.content;
}

pub fn _subroutineDec(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, label_counter: *usize) anyerror!void {
    std.debug.print("subroutine declaration\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    var function_table = FunctionMap.init(allocator);
    defer function_table.deinit();

    var num_arguments: u32 = 0;

    var is_method = false;

    // if this is a method we need to add 1 more argument for the 'this' pointer
    if (current_token.equals(tokens.method_kw)) {
        is_method = true;
        num_arguments += 1;
    }

    // get over the subroutine keyword
    try proceed(current);

    // ignore the return type
    try proceed(current);

    // ignore the subroutine name
    const function_name = try _subroutineName(tokens_list, current);

    // ignore the '('
    try proceed(current);

    num_arguments += try _parameterList(tokens_list, current, &function_table);

    const declaration_code = try std.fmt.allocPrint(allocator, "function {s} {d}\n", .{ function_name, num_arguments });
    try writeCode(writer, declaration_code);
    allocator.free(declaration_code);

    if (is_method) {
        // if this is a method, we need to add 1 more argument for the 'this' pointer
        var code = try std.fmt.allocPrint(allocator, "push argument 0\n", .{});
        try writeCode(writer, code);
        allocator.free(code);
        code = try std.fmt.allocPrint(allocator, "pop pointer 0\n", .{});
        try writeCode(writer, code);
    }

    // ignore the ')'
    try proceed(current);

    try _subroutineBody(allocator, writer, tokens_list, current, class_table, &function_table, label_counter);
}

fn _parameterList(tokens_list: std.ArrayList(Token), current: *usize, function_table: *FunctionMap) anyerror!u32 {
    std.debug.print("parameter list\n", .{});

    const current_token = (try peek(tokens_list, (current.*)));

    var num_arguments: u32 = 0;

    if ((current_token.equals(tokens.int_kw)) or (current_token.equals(tokens.char_kw)) or (current_token.equals(tokens.boolean_kw)) or (current_token.equals(tokens.identifier))) {
        var var_type: []const u8 = try _type(tokens_list, current);

        var var_name: []const u8 = try _varName(tokens_list, current);

        function_table.put(var_name, records.FunctionRecord.init(var_type, true, num_arguments)) catch unreachable;

        num_arguments += 1;

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            // ignore ','
            try proceed(current);

            var_type = try _type(tokens_list, current);

            var_name = try _varName(tokens_list, current);

            function_table.put(var_name, records.FunctionRecord.init(var_type, true, num_arguments)) catch unreachable;

            num_arguments += 1;
        }
    }

    return num_arguments;
}

fn _subroutineBody(allocator: std.mem.Allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *ClassMap, function_table: *FunctionMap, label_counter: *usize) anyerror!void {
    std.debug.print("subroutine body\n", .{});

    // ignore the '{'
    try proceed(current);

    var local_counter: usize = 0;

    while ((try peek(tokens_list, (current.*))).equals(tokens.var_kw)) {
        try _varDec(tokens_list, current, function_table, &local_counter);
    }

    try _statements(allocator, writer, tokens_list, current, class_table, function_table, label_counter);

    // ignore the '}'
    try proceed(current);
}

fn _varDec(tokens_list: std.ArrayList(Token), current: *usize, function_table: *FunctionMap, local_counter: *usize) anyerror!void {
    std.debug.print("variable declaration\n", .{});

    // ignore 'var'
    try proceed(current);

    const var_type: []const u8 = try _type(tokens_list, current);

    var var_name: []const u8 = try _varName(tokens_list, current);

    function_table.put(var_name, records.FunctionRecord.init(var_type, false, local_counter.*)) catch unreachable;

    local_counter.* += 1;

    while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
        // ignore ','
        try proceed(current);

        var_name = try _varName(tokens_list, current);

        function_table.put(var_name, records.FunctionRecord.init(var_type, false, local_counter.*)) catch unreachable;

        local_counter.* += 1;
    }

    // ignore ';'
    try proceed(current);
}
