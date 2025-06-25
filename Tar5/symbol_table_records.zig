const std = @import("std");

// struct of the Class table record
pub const ClassRecord = struct {
    var_type: []const u8,
    static: bool,
    index: usize,

    pub fn init(var_type: []const u8, static: bool, index: u32) ClassRecord {
        return ClassRecord{
            .var_type = var_type,
            .static = static,
            .index = index,
        };
    }

    pub fn getSegment(self: ClassRecord) []const u8 {
        return if (self.static) "static" else "this";
    }
};

// struct of the Function table record
pub const FunctionRecord = struct {
    return_type: []const u8,
    argument: bool,
    index: usize,

    pub fn init(return_type: []const u8, argument: bool, index: u32) FunctionRecord {
        return FunctionRecord{
            .return_type = return_type,
            .argument = argument,
            .index = index,
        };
    }

    pub fn getSegment(self: FunctionRecord) []const u8 {
        return if (self.argument) "argument" else "local";
    }
};
