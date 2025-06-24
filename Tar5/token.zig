const std = @import("std");

// struct of the token entity
pub const Token = struct {
    lexeme: []const u8,
    content: []const u8,

    pub fn getLexeme(self: Token) []const u8 {
        return self.lexeme;
    }

    pub fn getContent(self: Token) []const u8 {
        return self.content;
    }

    pub fn init(lexeme: []const u8, content: []const u8) Token {
        return Token{
            .lexeme = lexeme,
            .content = content,
        };
    }

    // see if oour token is equal to another. if the content is # then it means that the content is'nt matter
    pub fn equals(self: Token, other: Token) bool {
        return std.mem.eql(u8, self.lexeme, other.lexeme) and
            (std.mem.eql(u8, self.content, other.content) or (std.mem.eql(u8, other.content, "#")));
    }
};
