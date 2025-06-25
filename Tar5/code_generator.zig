const std = @import("std");
const Token = @import("token.zig").Token;
const records = @import("symbol_table_records.zig");
const FunctionMap = std.AutoHashMap([]const u8, records.FunctionRecord);
const ClassMap = std.AutoHashMap([]const u8, records.ClassRecord);
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
fn insert_into_function_symbol_table(allocator: std.heap.page_allocator, function_table: FunctionMap, var_type: []const u8, is_argument: bool, index: *usize) anyerror!void {
    const record_ptr = allocator.create(records.FunctionRecord) catch unreachable;
    record_ptr.* = records.ClassRecord.init(var_type, is_argument, index);
    function_table.put(var_type, record_ptr.*) catch unreachable;

    index.* += 1;
}

// helping function to put some record inside the class symbol table
fn insert_into_class_symbol_table(allocator: std.heap.page_allocator, class_table: ClassMap, var_type: []const u8, is_static: bool, index: *usize) anyerror!void {
    const record_ptr = allocator.create(records.ClassRecord) catch unreachable;
    record_ptr.* = records.ClassRecord.init(var_type, is_static, index);
    class_table.put(var_type, record_ptr.*) catch unreachable;

    index.* += 1;
}

//--------------------------------------------------------
// the code writer functions:
//--------------------------------------------------------
pub fn _class(allocator: std.heap.page_allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: ClassMap, class_name: []const u8, static_counter: *usize, field_counter: *usize, label_counter: *usize) anyerror!void {

    // ignore 'class'
    try proceed(current);

    // go over the class name
    try _className(current);

    // ignore '{'
    try proceed(current);

    // while we have class variables, we will handle them
    while ((try peek(tokens_list, (current.*))).equals(tokens.static_kw) or (try peek(tokens_list, (current.*))).equals(tokens.field_kw)) {
        try _classVarDec(allocator, tokens_list, current, class_table, class_name, static_counter, field_counter);
    }

    // while we have subroutine declarations, we will handle them
    while ((try peek(tokens_list, (current.*))).equals(tokens.constructor_kw) or (try peek(tokens_list, (current.*))).equals(tokens.method_kw) or (try peek(tokens_list, (current.*))).equals(tokens.function_kw)) {
        try _subroutineDec(allocator, writer, tokens_list, current, class_table, label_counter);
    }

    // ignore '}'
    try proceed(current);

    return;
}

fn _ifStatement(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap, label_counter: *usize) anyerror!void {
    const current_label = label_counter.*;
    label_counter.* += 1;

    //ignore the 'if' keyword
    try proceed(current);

    //ignore the '('
    try proceed(current);

    try _expression(writer, tokens_list, current, class_table, function_table);

    writeCode(writer, "not\n if-goto L{d}\n", .{current_label});
    //ignore the ')'
    try proceed(current);

    // ignore the '{'
    try proceed(current);

    try _statements(writer, tokens_list, current, class_table, function_table, label_counter);

    // ignore the '}'
    try proceed(current);

    if ((try peek(tokens_list, (current.*))).equals(tokens.else_kw)) {
        const next_label = label_counter.*;
        label_counter.* += 1;

        writeCode(writer, "goto L{d}\nlabel{d}\n", .{ next_label, current_label });

        // ignore the 'else' keyword
        try proceed(current);

        // ignore the '{'
        try proceed(current);

        try _statements(writer, tokens_list, current, class_table, function_table, label_counter);

        writeCode(writer, "label L{d}\n", .{next_label});

        // ignore the '}'
        try proceed(current);
    } else {
        writeCode(writer, "label L{d}\n", .{current_label});
    }
}

fn _letStatement(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap) anyerror!void {

    //ignore the 'let' keyword
    try proceed(current);

    const var_name = try _varName(tokens_list, current);

    const var_record = function_table.get(var_name) orelse {
        class_table.get(var_name) orelse {
            std.debug.print("variable \"{s}\" not found in class or function symbol table!\n", .{var_name});
            std.process.exit(0);
        };
    };

    writeCode(writer, "push {s} {d}\n", .{ var_record.var_type, var_record.index });
    if ((try peek(tokens_list, (current.*))).equals(tokens.lbracket)) {

        // ignore the '['
        try proceed(current);

        try _expression(writer, tokens_list, current, class_table, function_table);

        // ignore the ']'
        try proceed(current);
    }

    // ignore the '='
    try proceed(current);

    try _expression(writer, tokens_list, current, class_table, function_table);

    // ignore the ';'
    try proceed(current);
}

fn _whileStatement(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap) anyerror!void {
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"whileStatement"});

    try proceed(writer, depth + 1, tokens_list, current, tokens.while_kw);

    try proceed(writer, depth + 1, tokens_list, current, tokens.lparen);

    try _expression(writer, depth + 1, tokens_list, current);

    try proceed(writer, depth + 1, tokens_list, current, tokens.rparen);

    try proceed(writer, depth + 1, tokens_list, current, tokens.lbrace);

    try _statements(writer, depth + 1, tokens_list, current);

    try proceed(writer, depth + 1, tokens_list, current, tokens.rbrace);

    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"/whileStatement"});
}

fn _statement(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap, label_counter: *usize) anyerror!void {
    if ((try peek(tokens_list, (current.*))).equals(tokens.if_kw)) {
        try _ifStatement(writer, tokens_list, current, class_table, function_table, label_counter);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.let_kw)) {
            try _letStatement(writer, tokens_list, current, class_table, function_table);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.while_kw)) {
                try _whileStatement(writer, tokens_list, current, class_table, function_table, label_counter);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.do_kw)) {
                    try _doStatement(writer, tokens_list, current, class_table, function_table);
                } else {
                    if ((try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
                        try _returnStatement(writer, tokens_list, current, class_table, function_table);
                    }
                }
            }
        }
    }
}

fn _statements(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap, label_counter: *usize) anyerror!void {
    while ((try peek(tokens_list, (current.*))).equals(tokens.if_kw) or (try peek(tokens_list, (current.*))).equals(tokens.let_kw) or (try peek(tokens_list, (current.*))).equals(tokens.while_kw) or (try peek(tokens_list, (current.*))).equals(tokens.do_kw) or (try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
        try _statement(writer, tokens_list, current, class_table, function_table, label_counter);
    }
}

fn _subroutineCall(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
        try _subroutineName(writer, depth, tokens_list, current);

        try proceed(writer, depth, tokens_list, current, tokens.lparen);

        try _expressionList(writer, depth, tokens_list, current);

        try proceed(writer, depth, tokens_list, current, tokens.rparen);
    } else {
        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
            try _varName(writer, depth, tokens_list, current);

            try proceed(writer, depth, tokens_list, current, tokens.dot);

            try _subroutineName(writer, depth, tokens_list, current);

            try proceed(writer, depth, tokens_list, current, tokens.lparen);

            try _expressionList(writer, depth, tokens_list, current);

            try proceed(writer, depth, tokens_list, current, tokens.rparen);
        } else {
            std.debug.print("unexpected token \"{s}\"!\n", .{(try peek(tokens_list, (current.*))).getContent()});
            std.process.exit(0);
        }
    }
}

fn _term(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"term"});

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant)) {
        try proceed(writer, depth + 1, tokens_list, current, tokens.integerConstant);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.stringConstant)) {
            try proceed(writer, depth + 1, tokens_list, current, tokens.stringConstant);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw)) {
                try _keywordConstant(writer, depth + 1, tokens_list, current);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.lparen)) {
                    try proceed(writer, depth + 1, tokens_list, current, tokens.lparen);

                    try _expression(writer, depth + 1, tokens_list, current);

                    try proceed(writer, depth + 1, tokens_list, current, tokens.rparen);
                } else {
                    if (((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) or ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier))) {
                        try _subroutineCall(writer, depth + 1, tokens_list, current);
                    } else {
                        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lbracket) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
                            try _varName(writer, depth + 1, tokens_list, current);

                            try proceed(writer, depth + 1, tokens_list, current, tokens.lbracket);

                            try _expression(writer, depth + 1, tokens_list, current);

                            try proceed(writer, depth + 1, tokens_list, current, tokens.rbracket);
                        } else {
                            if ((try peek(tokens_list, (current.*))).equals(tokens.tilde) or (try peek(tokens_list, (current.*))).equals(tokens.minus)) {
                                try _unaryOp(writer, depth + 1, tokens_list, current);

                                try _term(writer, depth + 1, tokens_list, current);
                            } else {
                                if (((try peek(tokens_list, (current.*))).equals(tokens.identifier)) and ((try peek(tokens_list, (current.*) + 1)).equals(tokens.rparen) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.rbracket) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.semicolon) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.comma) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.plus) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.minus) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.slash) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.star) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.pipe) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.amp) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.lt) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.gt) or (try peek(tokens_list, (current.*) + 1)).equals(tokens.equal))) {
                                    try _varName(writer, depth + 1, tokens_list, current);
                                } else {
                                    std.debug.print("unexpected token \"{s}\"!\n", .{(try peek(tokens_list, (current.*))).getContent()});
                                    std.process.exit(0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"/term"});
}

fn _expression(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap) anyerror!void {
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"expression"});

    try _term(writer, depth + 1, tokens_list, current);
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
        try _op(writer, depth + 1, tokens_list, current);

        try _term(writer, depth + 1, tokens_list, current);

        current_token = (try peek(tokens_list, (current.*)));
    }
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"/expression"});
}

fn _op(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if ((current_token.equals(tokens.plus)) or (current_token.equals(tokens.minus)) or (current_token.equals(tokens.star)) or (current_token.equals(tokens.slash)) or (current_token.equals(tokens.amp)) or (current_token.equals(tokens.pipe)) or (current_token.equals(tokens.gt)) or (current_token.equals(tokens.lt)) or (current_token.equals(tokens.equal))) {
        try proceed(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _doStatement(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: *SymbolMap, function_table: *SymbolMap) anyerror!void {
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"doStatement"});

    try proceed(writer, depth + 1, tokens_list, current, tokens.do_kw);

    try _subroutineCall(writer, depth + 1, tokens_list, current);

    try proceed(writer, depth + 1, tokens_list, current, tokens.semicolon);

    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"/doStatement"});
}

fn _returnStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try proceed(writer, depth + 1, tokens_list, current, tokens.return_kw);

    if (!(try peek(tokens_list, (current.*))).equals(tokens.semicolon)) {
        try _expression(writer, depth + 1, tokens_list, current);
    }

    try proceed(writer, depth + 1, tokens_list, current, tokens.semicolon);
}

fn _expressionList(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"expressionList"});

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant) or (try peek(tokens_list, (current.*))).equals(tokens.stringConstant) or (try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw) or (try peek(tokens_list, (current.*))).equals(tokens.identifier) or (try peek(tokens_list, (current.*))).equals(tokens.lparen) or (try peek(tokens_list, (current.*))).equals(tokens.minus) or (try peek(tokens_list, (current.*))).equals(tokens.tilde)) {
        try _expression(writer, depth + 1, tokens_list, current);

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            try proceed(writer, depth + 1, tokens_list, current, tokens.comma);

            try _expression(writer, depth + 1, tokens_list, current);
        }
    }

    try writePadding(writer, depth);
    try writer.print("<{s}>\n", .{"/expressionList"});
}

fn _keywordConstant(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.true_kw) or
        current_token.equals(tokens.false_kw) or
        current_token.equals(tokens.null_kw) or
        current_token.equals(tokens.this_kw))
    {
        try proceed(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _unaryOp(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.tilde) or current_token.equals(tokens.minus)) {
        try proceed(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _className(current: *usize) anyerror!void {
    try proceed(current);
}

fn _subroutineName(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]u8 {
    const result = (try peek(tokens_list, (current.*))).content;

    try proceed(current);

    return result;
}

fn _varName(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]const u8 {
    // get the variable name
    const result = (try peek(tokens_list, (current.*))).content;

    // get over the variable name
    try proceed(current, tokens.identifier);

    // return the variable name
    return result;
}

fn _classVarDec(allocator: std.heap.page_allocator, tokens_list: std.ArrayList(Token), current: *usize, class_table: SymbolMap, class_name: []const u8, static_counter: *usize, field_counter: *usize) anyerror!void {
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

    try insert_into_class_symbol_table(allocator, class_table, class_name, var_type, is_static, if (is_static) static_counter else field_counter);

    while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
        // ignore ','
        try proceed(current);

        var_name = try _varName(tokens_list, current);

        // add the class variable to the class symbol table
        try insert_into_class_symbol_table(allocator, class_table, var_type, is_static, if (is_static) static_counter.* else field_counter.*);
    }

    // ignore ';'
    try proceed(current);
}

fn _type(tokens_list: std.ArrayList(Token), current: *usize) anyerror![]const u8 {
    const current_token = (try peek(tokens_list, (current.*)));

    try proceed(current);
    return current_token.content;
}

pub fn _subroutineDec(allocator: std.heap.page_allocator, writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: SymbolMap, label_counter: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    const function_table = SymbolMap.init(allocator);
    defer function_table.deinit();

    var num_arguments: u32 = 0;

    // if this is a method we need to add 1 more argument for the 'this' pointer
    if (current_token.equals(tokens.method_kw)) {
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

    num_arguments += try _parameterList(tokens_list, current, function_table);

    const declaration_code = try std.fmt.allocPrint(allocator, "function {s} {d}\n", .{ function_name, num_arguments });
    defer allocator.free(declaration_code);

    writeCode(writer, declaration_code);

    // ignore the ')'
    try proceed(current);

    try _subroutineBody(writer, tokens_list, current, class_table, function_table, label_counter);
}

fn _parameterList(tokens_list: std.ArrayList(Token), current: *usize, function_table: SymbolMap) anyerror!u32 {
    const current_token = (try peek(tokens_list, (current.*)));

    var num_arguments: u32 = 0;

    if ((current_token.equals(tokens.int_kw)) or (current_token.equals(tokens.char_kw)) or (current_token.equals(tokens.boolean_kw)) or (current_token.equals(tokens.identifier))) {
        var var_type: []const u8 = try _type(tokens_list, current);

        var var_name: []const u8 = try _varName(tokens_list, current);

        function_table.put(var_name, records.SymbolRecord.init(var_type, true, num_arguments)) catch unreachable;

        num_arguments += 1;

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            // ignore ','
            try proceed(current);

            var_type = try _type(tokens_list, current);

            var_name = try _varName(tokens_list, current);

            function_table.put(var_name, records.SymbolRecord.init(var_type, true, num_arguments)) catch unreachable;

            num_arguments += 1;
        }
    }

    return num_arguments;
}

fn _subroutineBody(writer: anytype, tokens_list: std.ArrayList(Token), current: *usize, class_table: SymbolMap, function_table: SymbolMap, label_counter: *usize) anyerror!void {

    // ignore the '{'
    try proceed(current);

    var local_counter: usize = 0;

    while ((try peek(tokens_list, (current.*))).equals(tokens.var_kw)) {
        try _varDec(tokens_list, current, function_table, &local_counter);
    }

    try _statements(writer, tokens_list, current, class_table, function_table, label_counter);

    // ignore the '}'
    try proceed(current);
}

fn _varDec(tokens_list: std.ArrayList(Token), current: *usize, function_table: SymbolMap, local_counter: *usize) anyerror!void {

    // ignore 'var'
    try proceed(current);

    const var_type: []const u8 = try _type(tokens_list, current);

    var var_name: []const u8 = try _varName(tokens_list, current);

    function_table.put(var_name, records.SymbolRecord.init(var_type, false, local_counter)) catch unreachable;

    local_counter.* += 1;

    while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
        // ignore ','
        try proceed(current);

        var_name = try _varName(tokens_list, current);

        function_table.put(var_name, records.SymbolRecord.init(var_type, false, local_counter)) catch unreachable;

        local_counter.* += 1;
    }
}
