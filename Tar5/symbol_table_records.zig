const std = @import("std");

// struct of the symbol table record
pub const SymbolRecord = struct {
    var_type: []const u8,
    static_or_argument: bool,
    index: usize,

    pub fn init(var_type: []const u8, static_or_argument: bool, index: u32) SymbolRecord {
        return SymbolRecord{
            .var_type = var_type,
            .segment = static_or_argument,
            .index = index,
        };
    }
};
