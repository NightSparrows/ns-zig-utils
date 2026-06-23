///! An atomic reference counter for
/// resource to be share like shared pointer
const std = @import("std");

pub fn Arc(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        value: T,
        strong: std.atomic.Value(usize),

        /// create a shared structure with initial value
        pub fn init(allocator: std.mem.Allocator, value: T) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .value = value,
                .strong = std.atomic.Value(usize).init(1),
            };

            return self;
        }

        /// create a shader structure with undefined value
        pub fn create(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);

            self.* = .{
                .allocator = allocator,
                .value = undefined,
                .strong = std.atomic.Value(usize).init(1),
            };
            return self;
        }

        /// add a reference
        pub fn ref(self: *Self) *Self {
            _ = self.strong.fetchAdd(1, .acq_rel);
            return self;
        }

        /// deference
        /// I think you should set null after calling this function
        /// a.deref()
        /// a = undefeined;
        pub fn deref(self: *Self) void {
            if (self.strong.fetchSub(1, .acq_rel) == 1) {
                if (comptime std.meta.hasMethod(T, "deinit")) {
                    const deinit_info = @typeInfo(@TypeOf(T.deinit));

                    if (deinit_info == .@"fn") {
                        const params = deinit_info.@"fn".params;

                        if (params.len == 1) {
                            self.value.deinit();
                        } else if (params.len == 2) {
                            self.value.deinit(self.allocator);
                        } else {
                            @compileError("Arc: " ++ @typeName(T) ++ ".deinit not accepted.");
                        }
                    }
                }
                self.allocator.destroy(self);
            }
        }
    };
}
const testing = std.testing;

// 測試用結構體 1：deinit 不需要 allocator
const MockResourceNoAlloc = struct {
    deinit_called: *bool,

    pub fn deinit(self: MockResourceNoAlloc) void {
        self.deinit_called.* = true;
    }
};

// 測試用結構體 2：deinit 需要 allocator
const MockResourceWithAlloc = struct {
    deinit_called: *bool,
    ptr: *i32,

    pub fn deinit(self: MockResourceWithAlloc, allocator: std.mem.Allocator) void {
        allocator.destroy(self.ptr);
        self.deinit_called.* = true;
    }
};

test "Arc: 基礎引用與無參數 deinit 測試" {
    const allocator = testing.allocator;
    var deinit_called = false;

    // 1. 初始化 Arc
    const res = MockResourceNoAlloc{ .deinit_called = &deinit_called };
    var my_arc = try Arc(MockResourceNoAlloc).init(allocator, res);

    // 2. 測試引用計數增加
    _ = my_arc.ref();
    try testing.expectEqual(@as(usize, 2), my_arc.strong.load(.monotonic));

    // 3. 測試第一次釋放 (計數變 1，不該觸發 deinit)
    my_arc.deref();
    try testing.expect(!deinit_called);
    try testing.expectEqual(@as(usize, 1), my_arc.strong.load(.monotonic));

    // 4. 測試最後一次釋放 (計數變 0，應該觸發 deinit 並銷毀)
    my_arc.deref();
    try testing.expect(deinit_called);
}

test "Arc: 帶參數 deinit(allocator) 測試" {
    const allocator = testing.allocator;
    var deinit_called = false;

    // 分配內部子資源
    const dummy_ptr = try allocator.create(i32);
    dummy_ptr.* = 42;

    const res = MockResourceWithAlloc{
        .deinit_called = &deinit_called,
        .ptr = dummy_ptr,
    };

    var my_arc = try Arc(MockResourceWithAlloc).init(allocator, res);

    // 釋放，應該會自動辨識並傳入 allocator 給 deinit
    my_arc.deref();
    try testing.expect(deinit_called);
}

test "Arc: create(undefined) 延遲初始化測試" {
    const allocator = testing.allocator;
    var deinit_called = false;

    var my_arc = try Arc(MockResourceNoAlloc).create(allocator);

    // 延遲填入值 (類似 Vulkan API 的操作)
    my_arc.value = MockResourceNoAlloc{ .deinit_called = &deinit_called };

    my_arc.deref();
    try testing.expect(deinit_called);
}

// 多執行緒測試用的 Worker 函數
test "Arc: 壓力測試 - 多執行緒併發安全性" {
    const allocator = std.testing.allocator;
    var deinit_called = false;

    const workerFunc = struct {
        pub fn workerFunc(
            p_arc_ptr: anytype,
            p_io: std.Io,
            p_start_gate: *std.atomic.Value(bool),
        ) anyerror!void {
            while (!p_start_gate.load(.acquire)) {
                std.Thread.yield() catch {};
            }

            const local_ref = p_arc_ptr.ref();
            defer local_ref.deref();
            try std.Io.sleep(p_io, std.Io.Duration.fromNanoseconds(5 * std.time.ns_per_ms), .awake);
        }
    }.workerFunc;

    const res = MockResourceNoAlloc{ .deinit_called = &deinit_called };
    var my_arc = try Arc(MockResourceNoAlloc).init(allocator, res);

    var start_gate = std.atomic.Value(bool).init(false);

    const thread_count = 8;
    var threads: [thread_count]std.Thread = undefined;

    for (&threads) |*t| {
        t.* = try std.Thread.spawn(.{}, workerFunc, .{
            my_arc,
            testing.io,
            &start_gate,
        });
    }

    start_gate.store(true, .release);

    for (threads) |t| {
        t.join();
    }

    try testing.expectEqual(@as(usize, 1), my_arc.strong.load(.monotonic));
    try testing.expect(!deinit_called);

    my_arc.deref();
    try testing.expect(deinit_called);
}
