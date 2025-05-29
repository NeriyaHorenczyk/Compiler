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


const std = @import("std");
const fs = std.fs;
const Writer = std.io.Writer;
const mem = std.mem;


pub fn q0(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer : *std.ArrayList(u8), writer: Writer) !void {
    
    const _current = file_content[*current_character];

    //Checks if the current character is a digit.
    if(_current >= '0' and _current <= '9'){
        
        increment_character(_current, current_character, buffer);

        q2(allocator,
         file_content, 
         current_character, 
         buffer, 
         writer);
         return;
    }

    if(_current == '"'){
        increment_character(_current, current_character, buffer);

        q3(allocator,
         file_content,
          current_character,
           buffer,
           writer);
           return;
    }

    if(_current == '/'){

        increment_character(_current, current_character, buffer);

        q5(allocator,
         file_content,
          current_character,
           buffer,
           writer);
           return;
    }
    
    if((_current >= 'a' and _current <= 'z') or (_current >= 'A' and _current <= 'Z') or _current == '_'){
        
        increment_character(_current, current_character, buffer);

        q1(allocator,
         file_content,
          current_character,
           buffer,
            writer);

        return;
    }

    if(_current == '\n' or _current == '\t' or _current == ' '){
        current_character.* += 1;
        q0(allocator,
        file_content, 
        current_character,
        buffer, 
        writer);
        return;
    }

    q10(allocator, file_content, current_character, buffer, writer)
    
}

pub fn q1(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q2(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q3(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q4(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q5(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q6(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q7(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q8(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q9(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}

pub fn q10(allocator: std.mem.Allocator, file_content: []u8, current_character: *u8, buffer: *std.ArrayList(u8), writer: Writer) !void {}


// Increment the current characater by 1 and append the current character to the buffer.
fn increment_character(_current : u8,current_character: *u8, buffer : *std.ArrayList(u8)) !void {

        current_character.* += 1;
        (buffer.*).append(_current);        
        return;
}

fn buffer_to_writer(buffer: *std.ArrayList(u8), writer: Writer) !void {
    try writer.print("{s}", .{ (buffer.*).items });
}
