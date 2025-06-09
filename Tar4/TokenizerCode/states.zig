const std = @import("std");

// each keyword content, for clean comperation
const keywords = [_][]const u8{
    "class",  "constructor", "function", "method", "field",
    "static", "var",         "int",      "char",   "boolean",
    "void",   "true",        "false",    "null",   "this",
    "let",    "do",          "if",       "else",   "while",
    "return",
};

// each symbol content, for clean comperation
const symbols = [_][]const u8{
    "{", "}", "(", ")", "[", "]", ".", ",", ";", "+", "-", "*", "/", "&", "|", "<", ">", "=", "~",
};

pub fn q0(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // digit.
        if (_current >= '0' and _current <= '9') {
            try increment_character(_current, current_character, buffer);

            try q2(file_content, current_character, buffer, writer);
            return;
        }

        // start of quote
        if (_current == '"') {
            current_character.* = current_character.* + 1;

            try q3(file_content, current_character, buffer, writer);
            return;
        }

        // start of notation
        if (_current == '/') {
            try increment_character(_current, current_character, buffer);

            try q5(file_content, current_character, buffer, writer);
            return;
        }

        // start of identifier
        if ((_current >= 'a' and _current <= 'z') or (_current >= 'A' and _current <= 'Z') or _current == '_') {
            try increment_character(_current, current_character, buffer);

            try q1(file_content, current_character, buffer, writer);

            return;
        }

        // whitespace - ignore
        if (_current == '\n' or _current == '\t' or _current == ' ' or _current == '\r') {
            current_character.* = current_character.* + 1;
            try q0(file_content, current_character, buffer, writer);
            return;
        }

        // else: it is a symbol or error
        try increment_character(_current, current_character, buffer);
        try q10(file_content, current_character, buffer, writer);
        return;
    }
}

pub fn q1(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // continue of the identifier
        if ((_current >= 'a' and _current <= 'z') or (_current >= 'A' and _current <= 'Z') or (_current >= '0' and _current <= '9') or _current == '_') {
            try increment_character(_current, current_character, buffer);

            try q1(file_content, current_character, buffer, writer);

            return;
        }
    }

    // get the accumulated content so far
    const word = (buffer.*).items;

    // if it is a keyword the get a keyword token
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) {
            const lexeme: []const u8 = "keyword"[0..];
            try buffer_to_writer(buffer, lexeme, writer);
            return;
        }
    }

    // else: it's a identifier token
    const lexeme: []const u8 = "identifier"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q2(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // continue of the number
        if ((_current >= '0' and _current <= '9')) {
            try increment_character(_current, current_character, buffer);

            try q2(file_content, current_character, buffer, writer);

            return;
        }
    }

    //write it to the file as integerConstant token
    const lexeme: []const u8 = "integerConstant"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q3(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // if it is nor the end of the quote, continue to increase the stringConstant token
        if (_current != '"') {
            try increment_character(_current, current_character, buffer);

            try q3(file_content, current_character, buffer, writer);

            return;
        }

        // increment the character without accumulating the quote itself
        current_character.* = current_character.* + 1;

        // go to the state that gets the stringConstant out
        try q4(buffer, writer);

        return;
    }

    std.debug.print("ERROR! only one: \" !\n", .{});
}

pub fn q4(buffer: *std.ArrayList(u8), writer: anytype) !void {
    // write the stringConstant token to the file
    const lexeme: []const u8 = "stringConstant"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q5(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // if we starting now note then go to the note state
        if (_current == '/') {
            try increment_character(_current, current_character, buffer);

            try q6(file_content, current_character);

            return;
        }

        // multi line note
        if (_current == '*') {
            try increment_character(_current, current_character, buffer);

            try q7(file_content, current_character);

            return;
        }
    }

    // else: this is just slash symbol
    const lexeme: []const u8 = "symbol"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q6(file_content: []u8, current_character: *usize) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // if we did not went down a line' then continue the note
        if (_current != '\n') {
            current_character.* += 1;

            try q6(file_content, current_character);

            return;
        }
    }

    // line over - note over:)
    return;
}

pub fn q7(file_content: []u8, current_character: *usize) error{ IndexOutOfBounds, OutOfMemory }!void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        current_character.* += 1;

        // then we might end the note
        if (_current != '*') {
            try q7(file_content, current_character);
            return;
        }

        // else: continue the multiline note
        try q8(file_content, current_character);
        return;
    }
}

pub fn q8(file_content: []u8, current_character: *usize) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        current_character.* += 1;

        // then we might end the note, again
        if (_current == '*') {
            try q8(file_content, current_character);
            return;
        }

        // then the note is over:)
        if (_current == '/') {
            try q9();
            return;
        }

        // if not then go back to normal
        try q7(file_content, current_character);

        return;
    }
}

pub fn q9() !void {
    // :)
    return;
}

pub fn q10(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    // if it is a symbol, then write it to the file as symbol constant
    if (((buffer.*).items.len == 1) and isInSymbol(((buffer.*).items[0]))) {
        const lexeme: []const u8 = "symbol"[0..];
        try buffer_to_writer(buffer, lexeme, writer);
        return;
    }

    const _current = try getCurrentCharacter(file_content, current_character.*);

    // if we didn't get to the EOF
    if (_current != 0) {
        // if we need to start a real token
        if ((_current >= '0' and _current <= '9') or
            (_current >= 'a' and _current <= 'z') or
            (_current >= 'A' and _current <= 'Z') or
            (_current == '"') or
            (_current == ' ') or
            (_current == '\n') or
            (_current == '\t') or
            (_current == '\r') or
            isInSymbol(_current))
        {
            // what was until now is an error token!
            std.debug.print("ERROR!!! unidentified token: {s}\n", .{(buffer.*).items});
            return;
        }

        // continue to accumulate the error token
        try increment_character(_current, current_character, buffer);
        try q10(file_content, current_character, buffer, writer);

        return;
    }

    return;
}

// Increment the current character by 1 and append the current character to the buffer.
fn increment_character(_current: u8, current_character: *usize, buffer: *std.ArrayList(u8)) !void {
    current_character.* = current_character.* + 1;
    try (buffer.*).append(_current);
    return;
}

// write the content with the lexeme to the output file
pub fn buffer_to_writer(buffer: *std.ArrayList(u8), lexeme: []const u8, writer: anytype) !void {
    try writer.print("<{s}> ", .{lexeme});
    for (buffer.items) |c| {
        switch (c) {
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '&' => try writer.writeAll("&amp;"),
            '"' => try writer.writeAll("&quot;"),
            '\'' => try writer.writeAll("&apos;"),
            else => try writer.writeByte(c),
        }
    }
    try writer.print(" </{s}>\n", .{lexeme});
}

// Check if the character is in the symbols array.
fn isInSymbol(ch: u8) bool {
    for (symbols) |sym| {
        if (sym[0] == ch) return true;
    }
    return false;
}

// get the current character in the file
fn getCurrentCharacter(file_content: []u8, current_character: usize) !u8 {
    if (current_character >= file_content.len) {
        return 0;
    }
    return file_content[current_character];
}
