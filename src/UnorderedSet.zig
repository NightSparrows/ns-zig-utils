const std = @import("std");

/// 'T' is the value type store in this set,
///
/// 'TContext' is a struct contain eql(self, T, T) and hash(self, T) function
pub fn UnorderedSet(comptime T: type, comptime TContext: type) type {
    return struct {
        const SetHashMap = std.HashMap(
            T,
            void,
            TContext,
            std.hash_map.default_max_load_percentage,
        );

        //const KV = SetHashMap.KV;
        const Self = @This();

        pub const Iterator = SetHashMap.KeyIterator;

        // variable
        hash_map: SetHashMap,

        // functions
        pub fn init(a: std.mem.Allocator) Self {
            return .{
                .hash_map = SetHashMap.init(a),
            };
        }

        pub fn deinit(self: *Self) void {
            self.hash_map.deinit();
            self.* = undefined;
        }

        /// insert a object
        /// 'return' true means inserted, false means already contain it.
        pub fn insert(self: *Self, value: T) !bool {
            const gop = try self.hash_map.getOrPut(value);
            if (!gop.found_existing) {
                gop.key_ptr.* = value;
                return true;
            } else {
                return false;
            }
        }

        pub fn erase(self: *Self, value: T) bool {
            return self.hash_map.remove(value);
        }

        pub fn clear(self: *Self) void {
            self.hash_map.clearRetainingCapacity();
        }

        pub fn contain(self: *Self, value: T) bool {
            return self.hash_map.contains(value);
        }

        /// how many element in this set
        pub fn count(self: *const Self) usize {
            return self.hash_map.count();
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.hash_map.keyIterator();
        }

        pub fn allocator(self: *const Self) std.mem.Allocator {
            return self.hash_map.allocator;
        }

        /// clone the set,
        /// it just clone the memory
        pub fn clone(self: *Self) !Self {
            var cloned = self.*;
            cloned.hash_map = try self.hash_map.clone();

            return cloned;
        }

        pub fn cloneWithAllocator(self: *Self, new_allocator: std.mem.Allocator) std.mem.Allocator.Error!Self {
            const prev_allocator = self.hash_map.allocator;
            defer self.hash_map.allocator = prev_allocator;

            self.hash_map.allocator = new_allocator;
            const cloned = try self.clone();
            return cloned;
        }
    };
}
