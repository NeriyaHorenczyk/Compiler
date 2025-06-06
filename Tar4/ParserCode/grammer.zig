const std = @import("std");
const Token = @import("token.zig").Token;

fn writeTab(writer: anytype, depth: u8) !void {
    for (0..depth) |_| {
        try writer.print("\t");
    }
}

fn writeNode(writer: anytype, depth: u8, token: Token) !void {
    writeTab(writer, depth);
    try writer.print("<{s}> {s} </{s}>", .{ token.getLexeme(), token.getContent(), token.getLexeme() });
}

fn match(writer: anytype, depth: u8, tokens: std.ArrayList(Token), current: *usize, matched_token: Token) !void {
    const current_token = tokens.items[(current.*)];

    if (current_token.equals(matched_token)) {
        writeNode(writer, depth, current_token);
        current.* += 1;
        return;
    } else {
        std.debug.print("unexpected token {s}!\n", .{current_token.getContent()});
        std.os.exit(0);
    }
}

pub fn _class(writer: anytype, depth: u8, tokens: std.ArrayList(Token), current: *usize) !void {
    writeTab(writer, depth);
    try writer.print("<{s}>\n", .{"class"});

    try match(writer, depth + 1, tokens, current, Token.init("keyword", "class"));

    try _className(writer, depth + 1, tokens, current);

    try match(writer, depth + 1, tokens, current, Token.init("symbol", "{"));

    while (tokens.items[(current.*)].equals(Token.init("keyword", "static")) or tokens.items[(current.*)].equals(Token.init("keyword", "field"))) {
        try _classVarDec(writer, depth + 1, tokens, current);
    }

    while (tokens.items[(current.*)].equals(Token.init("keyword", "constructor")) or tokens.items[(current.*)].equals(Token.init("keyword", "method")) or tokens.items[(current.*)].equals(Token.init("keyword", "function"))) {
        try _subroutineDec(writer, depth + 1, tokens, current);
    }

    try match(writer, depth + 1, tokens, current, Token.init("symbol", "}"));

    return;
}
