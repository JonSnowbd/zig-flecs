const std = @import("std");
const flecs = @import("flecs.zig");
const utils = @import("utils.zig");

pub const Filter = struct {
    world: flecs.World,
    filter: *flecs.ecs_filter_t = undefined,

    /// filter iterator that lets you fetch components via get/getOpt
    /// TODO: is this thing necessary? Seems the other iterators are more then capable compared to this thing.
    const Iterator = struct {
        iter: flecs.ecs_iter_t,
        index: usize = 0,

        pub fn init(iter: flecs.ecs_iter_t) @This() {
            return .{ .iter = iter };
        }

        pub fn next(self: *@This()) ?void {
            if (self.index >= self.iter.count) {
                self.index = 0;
                if (!flecs.ecs_filter_next(&self.iter)) return null;
            }

            self.index += 1;
        }

        pub fn entity(self: *@This()) flecs.Entity {
            return flecs.Entity.init(flecs.World{ .world = self.iter.world}, self.iter.entities[self.index - 1]);
        }

        /// gets the index into the terms array of this type
        fn getTermIndex(self: @This(), comptime T: type) usize {
            const comp_id = utils.componentHandle(T).*;
            var i: usize = 0;
            while (i < self.iter.term_count) : (i += 1) {
                if (self.iter.terms[i].id == comp_id) return i;
            }
            unreachable;
        }

        /// gets a term that is not optional
        pub fn get(self: @This(), comptime T: type) *T {
            const index = self.getTermIndex(T);
            const column_index = self.iter.terms[index].index;
            return &utils.column(&self.iter, T, column_index + 1)[self.index - 1];
        }

        /// gets a term that is not optional but is readonly
        pub fn getConst(self: @This(), comptime T: type) *const T {
            const index = self.getTermIndex(T);
            const column_index = self.iter.terms[index].index;
            std.debug.assert(flecs.ecs_term_is_readonly(&self.iter, @intCast(i32, index + 1)));

            // const column_index = flecs.ecs_iter_find_column(&self.iter, utils.componentHandle(T).*);
            return &utils.column(&self.iter, T, column_index + 1)[self.index - 1];
        }

        /// gets a term that is optional. Returns null if it isnt found.
        pub fn getOpt(self: @This(), comptime T: type) ?*T {
            const index = self.getTermIndex(T);
            const column_index = self.iter.terms[index].index;
            var skip_term = flecs.componentHandle(T).* != flecs.ecs_term_id(&self.iter, @intCast(usize, column_index + 1));
            if (skip_term) return null;

            if (utils.columnOpt(&self.iter, T, column_index + 1)) |col| {
                return &col[self.index - 1];
            }
            return null;
        }

        /// gets a term that is optional and readonly. Returns null if it isnt found.
        pub fn getConstOpt(self: @This(), comptime T: type) ?*const T {
            const index = self.getTermIndex(T);
            std.debug.assert(flecs.ecs_term_is_readonly(&self.iter, @intCast(i32, index + 1)));

            const column_index = self.iter.terms[index].index;
            var skip_term = flecs.componentHandle(T).* != flecs.ecs_term_id(&self.iter, @intCast(usize, column_index + 1));
            if (skip_term) return null;

            if (utils.columnOpt(&self.iter, T, column_index + 1)) |col| {
                return &col[self.index - 1];
            }
            return null;
        }
    };

    pub fn init(world: flecs.World, builder: *flecs.QueryBuilder) @This() {
        var filter = @This(){ .world = world };
        filter.filter = std.heap.c_allocator.create(flecs.ecs_filter_t) catch unreachable;
        std.debug.assert(flecs.ecs_filter_init(world.world, filter.filter, &builder.query.filter) == 0);
        return filter;
    }

    pub fn deinit(self: *@This()) void {
        flecs.ecs_filter_fini(self.filter);
        std.heap.c_allocator.destroy(self.filter);
    }

    pub fn iterator(self: *@This()) Iterator {
        return Iterator.init(flecs.ecs_filter_iter(self.world.world, self.filter));
    }

    pub fn entityIterator(self: *@This(), comptime Components: type) flecs.EntityIterator(Components) {
        return flecs.EntityIterator(Components).init(flecs.ecs_filter_iter(self.world.world, self.filter), flecs.ecs_filter_next);
    }

    pub fn tableIterator(self: *@This(), comptime Components: type) flecs.TableIterator(Components) {
        return flecs.TableIterator(Components).init(flecs.ecs_filter_iter(self.world.world, self.filter), flecs.ecs_filter_next);
    }

    pub fn each(self: *@This(), comptime func: anytype) void {
        const Components = switch (@typeInfo(@TypeOf(func))) {
            .BoundFn => |func_info| func_info.args[1].arg_type.?,
            .Fn => |func_info| func_info.args[0].arg_type.?,
            else => std.debug.assert("invalid func"),
        };

        var iter = self.entityIterator(Components);
        while (iter.next()) |comps| {
            @call(.{ .modifier = .always_inline }, func, .{comps});
        }
    }
};