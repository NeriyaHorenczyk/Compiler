const std = @import("std");
const Token = @import("token.zig").Token;
const tokens = @import("tokens.zig");

fn peek(tokens_list: std.ArrayList(Token), index: usize) !Token {
    return tokens_list.items[(index)];
}

fn writeTab(writer: anytype, depth: u8) !void {
    for (0..depth) |_| {
        try writer.print("\t");
    }
}

fn writeNode(writer: anytype, depth: u8, token: Token) !void {
    writeTab(writer, depth);
    try writer.print("<{s}> {s} </{s}>\n", .{ token.getLexeme(), token.getContent(), token.getLexeme() });
}

fn match(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize, matched_token: Token) !void {
    const current_token = peek(tokens_list, (current.*));

    if (current_token.equals(matched_token)) {
        writeNode(writer, depth, current_token);
        current.* += 1;
        return;
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.os.exit(0);
    }
}

//--------------------------------------------------------
// the grammar:
//--------------------------------------------------------
pub fn _class(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"class"});

    try match(writer, depth + 1, tokens_list, current, tokens.class_kw);

    try _className(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    while (peek(tokens_list, (current.*)).equals(tokens.static_kw) or peek(tokens_list, (current.*)).equals(tokens.field_kw)) {
        try _classVarDec(writer, depth + 1, tokens_list, current);
    }

    while (peek(tokens_list, (current.*)).equals(tokens.constructor_kw) or peek(tokens_list, (current.*)).equals(tokens.method_kw) or peek(tokens_list, (current.*)).equals(tokens.function_kw)) {
        try _subroutineDec(writer, depth + 1, tokens_list, current);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    writeTab(writer, depth);
    try writer.print("</{s}>\n", .{"class"});

    return;
}

fn _ifStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"ifStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.if_kw);

    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rparen);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    try _statements(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    if (peek(tokens_list, (current.*)).equals(tokens.else_kw)) {
        try match(writer, depth + 1, tokens_list, current, tokens.else_kw);

        try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

        try _statements(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rbrace);
    }

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/ifStatement"});
}

fn _letStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"letStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.let_kw);

    try _varName(writer, depth + 1, tokens_list, current);

    if (peek(tokens_list, (current.*)).equals(tokens.lbracket)) {
        try match(writer, depth + 1, tokens_list, current, tokens.lbracket);

        try _expression(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rbracket);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.equal);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.semicolon);

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/letStatement"});
}

fn _whileStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"whileStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.while_kw);

    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rparen);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    try _statements(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/whileStatement"});
}

fn _statement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"statement"});

    if (peek(tokens_list, (current.*)).equals(tokens.if_kw)) {
        try _ifStatement(writer, depth + 1, tokens_list, current);
    } else {
        if (peek(tokens_list, (current.*)).equals(tokens.let_kw)) {
            try _letStatement(writer, depth + 1, tokens_list, current);
        } else {
            if (peek(tokens_list, (current.*)).equals(tokens.while_kw)) {
                try _whileStatement(writer, depth + 1, tokens_list, current);
            } else {
                if (peek(tokens_list, (current.*)).equals(tokens.do_kw)) {
                    try _doStatement(writer, depth + 1, tokens_list, current);
                } else {
                    if (peek(tokens_list, (current.*)).equals(tokens.return_kw)) {
                        try _returnStatement(writer, depth + 1, tokens_list, current);
                    } else {
                        std.debug.print("unexpected token \"{s}\"!\n", .{peek(tokens_list, (current.*)).getContent()});
                        std.os.exit(0);
                    }
                }
            }
        }
    }

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/statement"});
}

fn _statements(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"statements"});

    while (peek(tokens_list, (current.*)).equals(tokens.if_kw) or peek(tokens_list, (current.*)).equals(tokens.let_kw) or peek(tokens_list, (current.*)).equals(tokens.while_kw) or peek(tokens_list, (current.*)).equals(tokens.do_kw) or peek(tokens_list, (current.*)).equals(tokens.return_kw)) {
        try _statement(writer, depth + 1, tokens_list, current);
    }

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/statements"});
}

fn _subroutineCall(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"subroutineCall"});

    if (peek(tokens_list, (current.*) + 1).equals(tokens.lparen) and peek(tokens_list, (current.*)).equals(tokens.identifier)) {
        try _subroutineName(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.lparen);

        try _expressionList(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rparen);
    } else {
        if (peek(tokens_list, (current.*) + 1).equals(tokens.dot) and peek(tokens_list, (current.*)).equals(tokens.identifier)) {
            try _varName(writer, depth + 1, tokens_list, current);

            try match(writer, depth + 1, tokens_list, current, tokens.dot);

            try _subroutineName(writer, depth + 1, tokens_list, current);

            try match(writer, depth + 1, tokens_list, current, tokens.lparen);

            try _expressionList(writer, depth + 1, tokens_list, current);

            try match(writer, depth + 1, tokens_list, current, tokens.rparen);
        } else {
            std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
            std.os.exit(0);
        }
    }

    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/subroutineCall"});
}

fn _term(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"term"});

    if (peek(tokens_list, (current.*)).equals(tokens.integerConstant)) {
        try match(writer, depth + 1, tokens_list, current, tokens.integerConstant);
    } else {
        if (peek(tokens_list, (current.*)).equals(tokens.stringConstant)) {
            try match(writer, depth + 1, tokens_list, current, tokens.stringConstant);
        } else {
            if (peek(tokens_list, (current.*)).equals(tokens.true_kw) or peek(tokens_list, (current.*)).equals(tokens.false_kw) or peek(tokens_list, (current.*)).equals(tokens.null_kw) or peek(tokens_list, (current.*)).equals(tokens.this_kw)) {
                try _keywordConstant(writer, depth + 1, tokens_list, current);
            } else {
                if (peek(tokens_list, (current.*)).equals(tokens.lparen)) {
                    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

                    try _expression(writer, depth + 1, tokens_list, current);

                    try match(writer, depth + 1, tokens_list, current, tokens.rparen);
                } else {
                    if (peek(tokens_list, (current.*) + 1).equals(tokens.lparen) and peek(tokens_list, (current.*)).equals(tokens.identifier)) {
                        try _subroutineCall(writer, depth + 1, tokens_list, current);
                    } else {
                        if (peek(tokens_list, (current.*) + 1).equals(tokens.lbracket) and peek(tokens_list, (current.*)).equals(tokens.identifier)) {
                            try _varName(writer, depth + 1, tokens_list, current);

                            try match(writer, depth + 1, tokens_list, current, tokens.lbracket);

                            try _expression(writer, depth + 1, tokens_list, current);

                            try match(writer, depth + 1, tokens_list, current, tokens.rbracket);
                        } else {
                            if (peek(tokens_list, (current.*)).equals(tokens.tilde) or peek(tokens_list, (current.*)).equals(tokens.minus)) {
                                try unaryOp(writer, depth + 1, tokens_list, current);

                                try _term(writer, depth + 1, tokens_list, current);
                            } else {
                                if ((peek(tokens_list, (current.*)).equals(tokens.identifier)) and (peek(tokens_list, (current.*) + 1).equals(tokens.rparen) or peek(tokens_list, (current.*) + 1).equals(tokens.rbracket) or peek(tokens_list, (current.*) + 1).equals(tokens.semicolon) or peek(tokens_list, (current.*) + 1).equals(tokens.comma) or peek(tokens_list, (current.*) + 1).equals(tokens.plus) or peek(tokens_list, (current.*) + 1).equals(tokens.minus) or peek(tokens_list, (current.*) + 1).equals(tokens.slash) or peek(tokens_list, (current.*) + 1).equals(tokens.star) or peek(tokens_list, (current.*) + 1).equals(tokens.pipe) or peek(tokens_list, (current.*) + 1).equals(tokens.amp) or peek(tokens_list, (current.*) + 1).equals(tokens.lt) or peek(tokens_list, (current.*) + 1).equals(tokens.gt) or peek(tokens_list, (current.*) + 1).equals(tokens.equal))) {
                                    try _varName(writer, depth + 1, tokens_list, current);
                                } else {
                                    std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
                                    std.os.exit(0);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/term"});
}
