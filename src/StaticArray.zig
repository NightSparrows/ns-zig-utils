const std = @import("std");

/// Non heap array
pub fn StaticArray(comptime T: type, comptime max_size: usize) type {
    return struct {
        const Self = @This();

        size: usize = 0,
        value: [max_size]T = undefined,

        pub const init = Self{};

        pub const Error = error{Overflow};

        pub fn slice(self: anytype) matchSelfType(self, []T, []const T) {
            return self.value[0..self.size];
        }

        pub fn append(self: *Self, value: T) Error!void {
            if (self.size >= max_size) {
                return Error.Overflow;
            }

            self.value[self.size] = value;
            self.size += 1;
        }

        // add one with uninit value
        pub fn addOne(self: *Self) Error!*T {
            if (self.size >= max_size) {
                return Error.Overflow;
            }

            const ptr = &self.value[self.size];
            self.size += 1;
            return ptr;
        }

        /// 彈出最後一個元素
        pub fn pop(self: *Self) ?T {
            if (self.size == 0) return null;
            self.size -= 1;
            return self.value[self.size];
        }

        pub fn clear(self: *Self) void {
            self.size = 0;
        }

        pub fn capacity(self: *Self) usize {
            return self.value.len;
        }

        /// 內部輔助：用來讓 slice() 函數同時支援 const 和變數指標
        fn matchSelfType(self: anytype, comptime VarType: type, comptime ConstType: type) type {
            return if (@typeInfo(@TypeOf(self)).pointer.is_const) ConstType else VarType;
        }

        pub fn len(self: *Self) usize {
            return self.size;
        }
    };
}
