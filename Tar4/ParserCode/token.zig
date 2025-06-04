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
};
