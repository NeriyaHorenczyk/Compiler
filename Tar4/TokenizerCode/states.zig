const std = @import("std");

const keywords = [_][]const u8{
    "class",  "constructor", "function", "method", "field",
    "static", "var",         "int",      "char",   "boolean",
    "void",   "true",        "false",    "null",   "this",
    "let",    "do",          "if",       "else",   "while",
    "return",
};

const symbols = [_][]const u8{
    "{", "}", "(", ")", "[", "]", ".", ",", ";", "+", "-", "*", "/", "&", "|", "<", ">", "=", "~",
};

pub fn q0(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        //Checks if the current character is a digit.
        if (_current >= '0' and _current <= '9') {
            try increment_character(_current, current_character, buffer);

            try q2(file_content, current_character, buffer, writer);
            return;
        }

        if (_current == '"') {
            current_character.* = current_character.* + 1;

            try q3(file_content, current_character, buffer, writer);
            return;
        }

        if (_current == '/') {
            try increment_character(_current, current_character, buffer);

            try q5(file_content, current_character, buffer, writer);
            return;
        }

        if ((_current >= 'a' and _current <= 'z') or (_current >= 'A' and _current <= 'Z') or _current == '_') {
            try increment_character(_current, current_character, buffer);

            try q1(file_content, current_character, buffer, writer);

            return;
        }

        if (_current == '\n' or _current == '\t' or _current == ' ' or _current == '\r') {
            current_character.* = current_character.* + 1;
            try q0(file_content, current_character, buffer, writer);
            return;
        }

        try increment_character(_current, current_character, buffer);
        try q10(file_content, current_character, buffer, writer);
        return;
    }
}

pub fn q1(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        if ((_current >= 'a' and _current <= 'z') or (_current >= 'A' and _current <= 'Z') or (_current >= '0' and _current <= '9') or _current == '_') {
            try increment_character(_current, current_character, buffer);

            try q1(file_content, current_character, buffer, writer);

            return;
        }
    }

    const word = (buffer.*).items;

    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) {
            const lexeme: []const u8 = "keyword"[0..];
            try buffer_to_writer(buffer, lexeme, writer);
            return;
        }
    }

    const lexeme: []const u8 = "identifier"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q2(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        if ((_current >= '0' and _current <= '9')) {
            try increment_character(_current, current_character, buffer);

            try q2(file_content, current_character, buffer, writer);

            return;
        }
    }

    const lexeme: []const u8 = "integerConstant"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q3(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        if (_current != '"') {
            try increment_character(_current, current_character, buffer);

            try q3(file_content, current_character, buffer, writer);

            return;
        }

        current_character.* = current_character.* + 1;

        try q4(buffer, writer);

        return;
    }

    std.debug.print("ERROR! only one: \" !\n", .{});
}

pub fn q4(buffer: *std.ArrayList(u8), writer: anytype) !void {
    const lexeme: []const u8 = "stringConstant"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q5(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        if (_current == '/') {
            try increment_character(_current, current_character, buffer);

            try q6(file_content, current_character);

            return;
        }

        if (_current == '*') {
            try increment_character(_current, current_character, buffer);

            try q7(file_content, current_character);

            return;
        }
    }

    const lexeme: []const u8 = "symbol"[0..];
    try buffer_to_writer(buffer, lexeme, writer);
    return;
}

pub fn q6(file_content: []u8, current_character: *usize) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        if (_current != '\n') {
            current_character.* += 1;

            try q6(file_content, current_character);

            return;
        }
    }

    return;
}

pub fn q7(file_content: []u8, current_character: *usize) error{ IndexOutOfBounds, OutOfMemory }!void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        current_character.* += 1;

        if (_current != '*') {
            try q7(file_content, current_character);
            return;
        }

        try q8(file_content, current_character);
        return;
    }
}

pub fn q8(file_content: []u8, current_character: *usize) !void {
    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
        current_character.* += 1;

        if (_current == '*') {
            try q8(file_content, current_character);
            return;
        }

        if (_current == '/') {
            try q9();
            return;
        }

        try q7(file_content, current_character);

        return;
    }
}

pub fn q9() !void {
    return;
}

pub fn q10(file_content: []u8, current_character: *usize, buffer: *std.ArrayList(u8), writer: anytype) !void {
    if (((buffer.*).items.len == 1) and isInSymbol(((buffer.*).items[0]))) {
        const lexeme: []const u8 = "symbol"[0..];
        try buffer_to_writer(buffer, lexeme, writer);
        return;
    }

    const _current = try getCurrentCharacter(file_content, current_character.*);

    if (_current != 0) {
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
            std.debug.print("ERROR!!! unidentified token: {s}\n", .{(buffer.*).items});
            return;
        }

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

fn getCurrentCharacter(file_content: []u8, current_character: usize) !u8 {
    if (current_character >= file_content.len) {
        return 0;
    }
    return file_content[current_character];
}
