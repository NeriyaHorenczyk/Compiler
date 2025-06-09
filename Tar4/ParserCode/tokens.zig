const Token = @import("token.zig").Token;

// Symbols
pub const lparen = Token.init("symbol", "(");
pub const rparen = Token.init("symbol", ")");
pub const lbracket = Token.init("symbol", "[");
pub const rbracket = Token.init("symbol", "]");
pub const lbrace = Token.init("symbol", "{");
pub const rbrace = Token.init("symbol", "}");
pub const comma = Token.init("symbol", ",");
pub const dot = Token.init("symbol", ".");
pub const semicolon = Token.init("symbol", ";");
pub const equal = Token.init("symbol", "=");
pub const plus = Token.init("symbol", "+");
pub const minus = Token.init("symbol", "-");
pub const star = Token.init("symbol", "*");
pub const slash = Token.init("symbol", "/");
pub const amp = Token.init("symbol", "&amp;");
pub const pipe = Token.init("symbol", "|");
pub const tilde = Token.init("symbol", "~");
pub const lt = Token.init("symbol", "&lt;");
pub const gt = Token.init("symbol", "&gt;");

// Keywords
pub const class_kw = Token.init("keyword", "class");
pub const constructor_kw = Token.init("keyword", "constructor");
pub const method_kw = Token.init("keyword", "method");
pub const function_kw = Token.init("keyword", "function");
pub const int_kw = Token.init("keyword", "int");
pub const boolean_kw = Token.init("keyword", "boolean");
pub const char_kw = Token.init("keyword", "char");
pub const void_kw = Token.init("keyword", "void");
pub const var_kw = Token.init("keyword", "var");
pub const static_kw = Token.init("keyword", "static");
pub const field_kw = Token.init("keyword", "field");
pub const let_kw = Token.init("keyword", "let");
pub const do_kw = Token.init("keyword", "do");
pub const if_kw = Token.init("keyword", "if");
pub const else_kw = Token.init("keyword", "else");
pub const while_kw = Token.init("keyword", "while");
pub const return_kw = Token.init("keyword", "return");
pub const true_kw = Token.init("keyword", "true");
pub const false_kw = Token.init("keyword", "false");
pub const null_kw = Token.init("keyword", "null");
pub const this_kw = Token.init("keyword", "this");

//identifier
pub const identifier = Token.init("identifier", "#");

//integerConstant
pub const integerConstant = Token.init("integerConstant", "#");

//stringConstant
pub const stringConstant = Token.init("stringConstant", "#");
