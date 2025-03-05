const std = @import("std");
const sapp = @import("sokol").app;
const sg = @import("sokol").gfx;
const sglue = @import("sokol").glue;
const slog = @import("sokol").log;
const linalg = @import("linalg");
const shd = @import("shader.zig");

// UTILS

pub const MAX_KEYCODES = sapp.max_keycodes;
pub const DEFAULT_UV = Vec4{ 0, 0, 1, 1 };
pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);
pub const Matrix4 = linalg.Matrix(4, f32);

const AppState = struct {
    pass_action: sg.PassAction,
    pip: sg.Pipeline,
    bind: sg.Bindings,
    input_state: InputState,
    player_pos: Vec2,
    y_velocity: f32,
    on_ground: bool,

    pub fn init() AppState {
        return .{
            .pass_action = .{},
            .pip = .{},
            .bind = .{},
            .input_state = InputState.init(),
            .player_pos = Vec2{ 100, 100 },
            .y_velocity = 0,
            .on_ground = false,
        };
    }
};

var state = AppState.init();

const InputStateFlags = enum(u8) {
    down,
    just_pressed,
    just_released,
    repeat,
};

const InputState = struct {
    keys: [MAX_KEYCODES]std.bit_set.StaticBitSet(@typeInfo(InputStateFlags).Enum.fields.len),
    mouse_pos: Vec2,

    pub fn init() InputState {
        var result = InputState{
            .keys = undefined,
            .mouse_pos = Vec2{ 0, 0 },
        };

        @setEvalBranchQuota(100000);
        for (0..MAX_KEYCODES) |i| {
            result.keys[i] = std.bit_set.StaticBitSet(@typeInfo(InputStateFlags).Enum.fields.len).initEmpty();
        }

        return result;
    }
};

export fn init() void {
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });

    // zig fmt: off
    const vertices = [_]f32{
        // pos(2)     // color(4)                // uv(2)      // bytes(4)                // color_override(4)
        -0.5, -0.5,   1.0, 0.0, 0.0, 1.0,        0.0, 0.0,     0.0, 0.0, 0.0, 0.0,       0.0, 0.0, 0.0, 0.0,
         0.5, -0.5,   0.0, 1.0, 0.0, 1.0,        1.0, 0.0,     0.0, 0.0, 0.0, 0.0,       0.0, 0.0, 0.0, 0.0,
         0.5,  0.5,   0.0, 0.0, 1.0, 1.0,        1.0, 1.0,     0.0, 0.0, 0.0, 0.0,       0.0, 0.0, 0.0, 0.0,
        -0.5,  0.5,   1.0, 1.0, 0.0, 1.0,        0.0, 1.0,     0.0, 0.0, 0.0, 0.0,       0.0, 0.0, 0.0, 0.0,
    };

    const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

    state.bind.vertex_buffers[0] = sg.makeBuffer(.{
        .data = sg.asRange(&vertices),
    });

    state.bind.index_buffer = sg.makeBuffer(.{
        .type = .INDEXBUFFER,
        .data = sg.asRange(&indices),
    });

    const white_pixel = [_]u32{0xFFFFFFFF};

    state.bind.images[0] = sg.makeImage(.{
        .width = 1,
        .height = 1,
        .data = .{
            .subimage = [6][16]sg.Range{
                [16]sg.Range{
                    sg.asRange(&white_pixel),
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
            },
        },
    });

    state.bind.images[1] = sg.makeImage(.{
        .width = 1,
        .height = 1,
        .data = .{
            .subimage = [6][16]sg.Range{
                [16]sg.Range{
                    sg.asRange(&white_pixel),
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                    .{},
                },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
                [16]sg.Range{ .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{} },
            },
        },
    });

    state.bind.samplers[0] = sg.makeSampler(.{
        .min_filter = .NEAREST,
        .mag_filter = .NEAREST,
    });

    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.quadShaderDesc(sg.queryBackend())),
        .index_type = .UINT16,
        .layout = .{
            .buffers = .{
                .{
                    // 16 floats per vertex
                    .stride = 16 * @sizeOf(f32),
                    .step_func = .PER_VERTEX,
                },
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
                .{},
            },
            .attrs = .{
                // position
                .{ .buffer_index = 0, .offset = 0, .format = .FLOAT2 },
                // color0
                .{ .buffer_index = 0, .offset = 2 * @sizeOf(f32), .format = .FLOAT4 },
                // uv0
                .{ .buffer_index = 0, .offset = 6 * @sizeOf(f32), .format = .FLOAT2 },
                // bytes0
                .{ .buffer_index = 0, .offset = 8 * @sizeOf(f32), .format = .FLOAT4 },
                // color_override0
                .{ .buffer_index = 0, .offset = 12 * @sizeOf(f32), .format = .FLOAT4 },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
                .{ .format = .INVALID },
            },
        },
    });

    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.3, .g = 0.5, .b = 0.8, .a = 1.0 },
    };
}

export fn frame() void {
    sg.beginPass(.{
        .action = state.pass_action,
        .swapchain = sglue.swapchain(),
    });

    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);
    sg.draw(0, 6, 1);

    sg.endPass();
    sg.commit();
}

export fn input(evt: ?*const sapp.Event) void {
    if (evt) |e| {
        switch (e.type) {
            .KEY_DOWN => {
                const key_code = @intFromEnum(e.key_code);
                if (key_code >= 0) {
                    const key_index = @as(usize, @intCast(key_code));
                    if (key_index < MAX_KEYCODES) {
                        state.input_state.keys[key_index].unset(@intFromEnum(InputStateFlags.down));
                        state.input_state.keys[key_index].set(@intFromEnum(InputStateFlags.just_released));
                    }
                }
            },
            .MOUSE_MOVE => {
                state.input_state.mouse_pos = Vec2{ e.mouse_x, e.mouse_y };
            },
            else => {},
        }
    }
}

export fn cleanup() void {
    sg.shutdown();
}

pub fn main() !void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = input,
        .width = 800,
        .height = 600,
        .window_title = "Sokol Window in Zig",
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}
