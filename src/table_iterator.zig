const std = @import("std");
const flecs = @import("flecs.zig");
const meta = @import("meta.zig");

pub fn TableIterator(comptime Components: type) type {
    std.debug.assert(@typeInfo(Components) == .Struct);

    const Columns = meta.TableIteratorData(Components);

    const InnerIterator = struct {
        data: Columns = undefined,
        count: i32,
    };

    return struct {
        iter: flecs.ecs_iter_t,
        nextFn: fn ([*c]flecs.ecs_iter_t) callconv(.C) bool,

        pub fn init(iter: flecs.ecs_iter_t, nextFn: fn ([*c]flecs.ecs_iter_t) callconv(.C) bool) @This() {
            meta.validateIterator(Components, iter);
            return .{
                .iter = iter,
                .nextFn = nextFn,
            };
        }

        pub fn next(self: *@This()) ?InnerIterator {
            if (!self.nextFn(&self.iter)) return null;

            var iter: InnerIterator = .{ .count = self.iter.count };
            inline for (@typeInfo(Components).Struct.fields) |field, i| {
                const is_optional = @typeInfo(field.field_type) == .Optional;
                const col_type = meta.FinalChild(field.field_type);
                if (meta.isConst(field.field_type)) std.debug.assert(flecs.ecs_term_is_readonly(&self.iter, i + 1));

                if (is_optional) @field(iter.data, field.name) = null;
                const column_index = self.iter.terms[i].index;
                var skip_term = if (is_optional) flecs.componentHandle(col_type).* != flecs.ecs_term_id(&self.iter, @intCast(usize, column_index + 1)) else false;

                // note that an OR is actually a single term!
                // std.debug.print("---- col_type: {any}, optional: {any}, i: {d}, col_index: {d}\n", .{ col_type, is_optional, i, column_index });
                if (!skip_term) {
                    if (flecs.columnOpt(&self.iter, col_type, column_index + 1)) |col| {
                        @field(iter.data, field.name) = col;
                    }
                }
            }

            return iter;
        }
    };
}
