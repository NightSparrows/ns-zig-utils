const std = @import("std");

const Self = @This();

// local variable
content: std.ArrayList(u8) = .empty,

// string size
size: usize = 0,

pub fn init(allocator: std.mem.Allocator) !Self {
    var ret: Self = .{};

    try ret.content.append(allocator, '\x00');
    return ret;
}

pub fn initWithValue(allocator: std.mem.Allocator, value: []const u8) !Self {
    var ret = Self{};
    try ret.append(allocator, value);
    return ret;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.content.deinit(allocator);
    self.* = undefined;
}

pub fn clone(self: *Self, allocator: std.mem.Allocator) std.mem.Allocator.Error!Self {
    var cloned = self.*;
    cloned.content = try cloned.content.clone(allocator);

    return cloned;
}

/// the compare function for std sorting ascii string
pub fn lessThanFn(_: void, left: Self, right: Self) bool {
    return std.mem.lessThan(u8, left.content.items[0..left.size], right.content.items[0..right.size]);
}

/// append string to the end of the current string
pub fn append(self: *Self, allocator: std.mem.Allocator, str: []const u8) !void {
    if (str.len == 0)
        return;
    var str_len: usize = str.len;
    for (0..str.len) |i| {
        if (str[i] == '\x00') {
            str_len = i;
            break;
        }
    }
    if (str_len == 0) {
        return;
    }

    const new_c_string_len = self.size + str_len + 1;
    try self.content.resize(allocator, new_c_string_len);
    @memcpy(self.content.items[self.size .. self.size + str_len], str[0..str_len]);
    self.size += str_len;
    self.content.items[self.size] = '\x00';
}

pub fn toString(self: *const Self) []const u8 {
    return self.content.items[0..self.size];
}

pub fn toCString(self: *const Self) [:0]const u8 {
    return self.content.items[0..self.size :0];
}

pub fn eql(self: *const Self, other: *const Self) bool {
    if (self.size != other.size)
        return false;

    for (0..self.size) |i| {
        if (self.content.items[i] != other.content.items[i])
            return false;
    }
    return true;
}

pub fn eqlRaw(self: *const Self, other: []const u8) bool {
    if (self.size != other.len)
        return false;

    for (0..self.size) |i| {
        if (self.content.items[i] != other[i])
            return false;
    }
    return true;
}
pub fn empty(self: *Self) bool {
    return self.size == 0;
}

test "zig string" {
    const hello = "hello";

    const testStruct = struct {
        pub fn testFunc(str: []const u8) void {
            std.debug.print("str len: {}\n", .{str.len});
        }
    };
    testStruct.testFunc(hello);
}
