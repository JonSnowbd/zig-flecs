const std = @import("std");
const flecs = @import("flecs");

const total_entities: i32 = 100_000;
pub const Velocity = struct { x: f32, y: f32, z: f64 = 0 };
pub const Position = struct { x: f32, y: f32 };

pub fn main() !void {
    var world = flecs.World.init();
    defer world.deinit();

    world.registerComponents(.{Position, Velocity});
    world.newSystem("Move", .on_update, "Position, Velocity", move);

    createEntities(&world);
    iterateEntities(world);
}

fn move(it: [*c]flecs.ecs_iter_t) callconv(.C) void {
    const positions = flecs.column(it, Position, 1);
    const velocities = flecs.column(it, Velocity, 2);

    var i: usize = 0;
    while (i < it.*.count) : (i += 1) {
        // std.debug.print("p: {d}, v: {d}\n", .{ positions[i], velocities[i] });
        positions[i].x += velocities[i].x;
        positions[i].y += velocities[i].y;
    }
}

fn createEntities(world: *flecs.World) void {
    var timer = std.time.Timer.start() catch unreachable;

    var i: usize = 0;
    while (i < total_entities) : (i += 1) {
        const e = world.newEntity();
        e.set(&Position{ .x = 100, .y = 100 });
        e.set(&Velocity{ .x = 5, .y = 5 });
    }

    var end = timer.lap();
    std.debug.print("create {d} entities: \t{d}\n", .{ total_entities, @intToFloat(f64, end) / 1000000000 });
}

fn iterateEntities(world: flecs.World) void {
    var timer = std.time.Timer.start() catch unreachable;
    world.progress(0);

    var end = timer.lap();
    std.debug.print("iterate entities: \t\t{d}\n", .{@intToFloat(f64, end) / 1000000000});
}
