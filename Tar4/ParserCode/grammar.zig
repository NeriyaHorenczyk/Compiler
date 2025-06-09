const std = @import("std");
const Token = @import("token.zig").Token;
const tokens = @import("tokens.zig");

fn peek(tokens_list: std.ArrayList(Token), index: usize) anyerror!Token {
    return tokens_list.items[(index)];
}

fn writeTab(writer: anytype, depth: u8) anyerror!void {
    for (0..depth) |_| {
        try writer.print("  ", .{});
    }
}

fn writeNode(writer: anytype, depth: u8, token: Token) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}> {s} </{s}>\n", .{ token.getLexeme(), token.getContent(), token.getLexeme() });
}

fn match(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize, matched_token: Token) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(matched_token)) {
        try writeNode(writer, depth, current_token);
        current.* += 1;
        return;
    } else {
        std.debug.print("{s} with {s}\nand {s} with {s}\n", .{ current_token.lexeme, matched_token.lexeme, current_token.content, matched_token.content });
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

//--------------------------------------------------------
// the grammar:
//--------------------------------------------------------
pub fn _class(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"class"});

    try match(writer, depth + 1, tokens_list, current, tokens.class_kw);

    try _className(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    while ((try peek(tokens_list, (current.*))).equals(tokens.static_kw) or (try peek(tokens_list, (current.*))).equals(tokens.field_kw)) {
        try _classVarDec(writer, depth + 1, tokens_list, current);
    }

    while ((try peek(tokens_list, (current.*))).equals(tokens.constructor_kw) or (try peek(tokens_list, (current.*))).equals(tokens.method_kw) or (try peek(tokens_list, (current.*))).equals(tokens.function_kw)) {
        try _subroutineDec(writer, depth + 1, tokens_list, current);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    try writeTab(writer, depth);
    try writer.print("</{s}>\n", .{"class"});

    return;
}

fn _ifStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"ifStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.if_kw);

    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rparen);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    try _statements(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    if ((try peek(tokens_list, (current.*))).equals(tokens.else_kw)) {
        try match(writer, depth + 1, tokens_list, current, tokens.else_kw);

        try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

        try _statements(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rbrace);
    }

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/ifStatement"});
}

fn _letStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"letStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.let_kw);

    try _varName(writer, depth + 1, tokens_list, current);

    if ((try peek(tokens_list, (current.*))).equals(tokens.lbracket)) {
        try match(writer, depth + 1, tokens_list, current, tokens.lbracket);

        try _expression(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rbracket);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.equal);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.semicolon);

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/letStatement"});
}

fn _whileStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"whileStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.while_kw);

    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

    try _expression(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rparen);

    try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

    try _statements(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.rbrace);

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/whileStatement"});
}

fn _statement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    if ((try peek(tokens_list, (current.*))).equals(tokens.if_kw)) {
        try _ifStatement(writer, depth, tokens_list, current);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.let_kw)) {
            try _letStatement(writer, depth, tokens_list, current);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.while_kw)) {
                try _whileStatement(writer, depth, tokens_list, current);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.do_kw)) {
                    try _doStatement(writer, depth, tokens_list, current);
                } else {
                    if ((try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
                        try _returnStatement(writer, depth, tokens_list, current);
                    } else {
                        std.debug.print("unexpected token \"{s}\"!\n", .{(try peek(tokens_list, (current.*))).getContent()});
                        std.process.exit(0);
                    }
                }
            }
        }
    }
}

fn _statements(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"statements"});

    while ((try peek(tokens_list, (current.*))).equals(tokens.if_kw) or (try peek(tokens_list, (current.*))).equals(tokens.let_kw) or (try peek(tokens_list, (current.*))).equals(tokens.while_kw) or (try peek(tokens_list, (current.*))).equals(tokens.do_kw) or (try peek(tokens_list, (current.*))).equals(tokens.return_kw)) {
        try _statement(writer, depth + 1, tokens_list, current);
    }

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/statements"});
}

fn _subroutineCall(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
        try _subroutineName(writer, depth, tokens_list, current);

        try match(writer, depth, tokens_list, current, tokens.lparen);

        try _expressionList(writer, depth, tokens_list, current);

        try match(writer, depth, tokens_list, current, tokens.rparen);
    } else {
        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
            try _varName(writer, depth, tokens_list, current);

            try match(writer, depth, tokens_list, current, tokens.dot);

            try _subroutineName(writer, depth, tokens_list, current);

            try match(writer, depth, tokens_list, current, tokens.lparen);

            try _expressionList(writer, depth, tokens_list, current);

            try match(writer, depth, tokens_list, current, tokens.rparen);
        } else {
            std.debug.print("unexpected token \"{s}\"!\n", .{(try peek(tokens_list, (current.*))).getContent()});
            std.process.exit(0);
        }
    }
}

fn _term(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"term"});

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant)) {
        try match(writer, depth + 1, tokens_list, current, tokens.integerConstant);
    } else {
        if ((try peek(tokens_list, (current.*))).equals(tokens.stringConstant)) {
            try match(writer, depth + 1, tokens_list, current, tokens.stringConstant);
        } else {
            if ((try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw)) {
                try _keywordConstant(writer, depth + 1, tokens_list, current);
            } else {
                if ((try peek(tokens_list, (current.*))).equals(tokens.lparen)) {
                    try match(writer, depth + 1, tokens_list, current, tokens.lparen);

                    try _expression(writer, depth + 1, tokens_list, current);

                    try match(writer, depth + 1, tokens_list, current, tokens.rparen);
                } else {
                    if (((try peek(tokens_list, (current.*) + 1)).equals(tokens.lparen) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) or ((try peek(tokens_list, (current.*) + 1)).equals(tokens.dot) and (try peek(tokens_list, (current.*))).equals(tokens.identifier))) {
                        try _subroutineCall(writer, depth + 1, tokens_list, current);
                    } else {
                        if ((try peek(tokens_list, (current.*) + 1)).equals(tokens.lbracket) and (try peek(tokens_list, (current.*))).equals(tokens.identifier)) {
                            try _varName(writer, depth + 1, tokens_list, current);

                            try match(writer, depth + 1, tokens_list, current, tokens.lbracket);

                            try _expression(writer, depth + 1, tokens_list, current);

                            try match(writer, depth + 1, tokens_list, current, tokens.rbracket);
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
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/term"});
}

fn _expression(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
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
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/expression"});
}

fn _op(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if ((current_token.equals(tokens.plus)) or (current_token.equals(tokens.minus)) or (current_token.equals(tokens.star)) or (current_token.equals(tokens.slash)) or (current_token.equals(tokens.amp)) or (current_token.equals(tokens.pipe)) or (current_token.equals(tokens.gt)) or (current_token.equals(tokens.lt)) or (current_token.equals(tokens.equal))) {
        try match(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _doStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"doStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.do_kw);

    try _subroutineCall(writer, depth + 1, tokens_list, current);

    try match(writer, depth + 1, tokens_list, current, tokens.semicolon);

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/doStatement"});
}

fn _returnStatement(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"returnStatement"});

    try match(writer, depth + 1, tokens_list, current, tokens.return_kw);

    if (!(try peek(tokens_list, (current.*))).equals(tokens.semicolon)) {
        try _expression(writer, depth + 1, tokens_list, current);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.semicolon);

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/returnStatement"});
}

fn _expressionList(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"expressionList"});

    if ((try peek(tokens_list, (current.*))).equals(tokens.integerConstant) or (try peek(tokens_list, (current.*))).equals(tokens.stringConstant) or (try peek(tokens_list, (current.*))).equals(tokens.true_kw) or (try peek(tokens_list, (current.*))).equals(tokens.false_kw) or (try peek(tokens_list, (current.*))).equals(tokens.null_kw) or (try peek(tokens_list, (current.*))).equals(tokens.this_kw) or (try peek(tokens_list, (current.*))).equals(tokens.identifier) or (try peek(tokens_list, (current.*))).equals(tokens.lparen) or (try peek(tokens_list, (current.*))).equals(tokens.minus) or (try peek(tokens_list, (current.*))).equals(tokens.tilde)) {
        try _expression(writer, depth + 1, tokens_list, current);

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            try match(writer, depth + 1, tokens_list, current, tokens.comma);

            try _expression(writer, depth + 1, tokens_list, current);
        }
    }

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/expressionList"});
}

fn _keywordConstant(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.true_kw) or
        current_token.equals(tokens.false_kw) or
        current_token.equals(tokens.null_kw) or
        current_token.equals(tokens.this_kw))
    {
        try match(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _unaryOp(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.tilde) or current_token.equals(tokens.minus)) {
        try match(writer, depth, tokens_list, current, current_token);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
}

fn _className(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try match(writer, depth, tokens_list, current, tokens.identifier);
}

fn _subroutineName(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try match(writer, depth, tokens_list, current, tokens.identifier);
}

fn _varName(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try match(writer, depth, tokens_list, current, tokens.identifier);
}

fn _classVarDec(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"classVarDec"});

    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.static_kw) or current_token.equals(tokens.field_kw)) {
        try match(writer, depth + 1, tokens_list, current, current_token);

        try _type(writer, depth + 1, tokens_list, current);

        try _varName(writer, depth + 1, tokens_list, current);

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            try match(writer, depth + 1, tokens_list, current, tokens.comma);

            try _varName(writer, depth + 1, tokens_list, current);
        }

        try match(writer, depth + 1, tokens_list, current, tokens.semicolon);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/classVarDec"});
}

fn _type(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.int_kw) or
        current_token.equals(tokens.boolean_kw) or
        current_token.equals(tokens.char_kw))
    {
        try match(writer, depth, tokens_list, current, current_token);
    } else {
        if (current_token.equals(tokens.identifier)) {
            try _className(writer, depth, tokens_list, current);
        } else {
            std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
            std.process.exit(0);
        }
    }
}

pub fn _subroutineDec(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"subroutineDec"});

    const current_token = (try peek(tokens_list, (current.*)));

    if (current_token.equals(tokens.constructor_kw) or
        current_token.equals(tokens.method_kw) or
        current_token.equals(tokens.function_kw))
    {
        try match(writer, depth + 1, tokens_list, current, current_token);

        if ((try peek(tokens_list, (current.*))).equals(tokens.void_kw)) {
            try match(writer, depth + 1, tokens_list, current, tokens.void_kw);
        } else {
            try _type(writer, depth + 1, tokens_list, current);
        }

        try _subroutineName(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.lparen);

        try _parameterList(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rparen);

        try _subroutineBody(writer, depth + 1, tokens_list, current);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{current_token.getContent()});
        std.process.exit(0);
    }
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/subroutineDec"});
}

fn _parameterList(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"parameterList"});

    const current_token = (try peek(tokens_list, (current.*)));

    if ((current_token.equals(tokens.int_kw)) or (current_token.equals(tokens.char_kw)) or (current_token.equals(tokens.boolean_kw)) or (current_token.equals(tokens.identifier))) {
        try _type(writer, depth + 1, tokens_list, current);

        try _varName(writer, depth + 1, tokens_list, current);

        while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
            try match(writer, depth + 1, tokens_list, current, tokens.comma);

            try _type(writer, depth + 1, tokens_list, current);

            try _varName(writer, depth + 1, tokens_list, current);
        }
    }

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/parameterList"});
}

fn _subroutineBody(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"subroutineBody"});

    if ((try peek(tokens_list, (current.*))).equals(tokens.lbrace)) {
        try match(writer, depth + 1, tokens_list, current, tokens.lbrace);

        while ((try peek(tokens_list, (current.*))).equals(tokens.var_kw)) {
            try _varDec(writer, depth + 1, tokens_list, current);
        }

        try _statements(writer, depth + 1, tokens_list, current);

        try match(writer, depth + 1, tokens_list, current, tokens.rbrace);
    } else {
        std.debug.print("unexpected token \"{s}\"!\n", .{(try peek(tokens_list, (current.*))).getContent()});
        std.process.exit(0);
    }
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/subroutineBody"});
}

fn _varDec(writer: anytype, depth: u8, tokens_list: std.ArrayList(Token), current: *usize) anyerror!void {
    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"varDec"});

    try match(writer, depth + 1, tokens_list, current, tokens.var_kw);

    try _type(writer, depth + 1, tokens_list, current);

    try _varName(writer, depth + 1, tokens_list, current);

    while ((try peek(tokens_list, (current.*))).equals(tokens.comma)) {
        try match(writer, depth + 1, tokens_list, current, tokens.comma);

        try _varName(writer, depth + 1, tokens_list, current);
    }

    try match(writer, depth + 1, tokens_list, current, tokens.semicolon);

    try writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"/varDec"});
}
