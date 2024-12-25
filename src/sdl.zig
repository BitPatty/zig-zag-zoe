const math = @import("std").math;
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

/// Represents a point with sub pixel precision
pub const PointF = struct {
    /// The X coordinate
    x: f32,
    /// The y coordinate
    y: f32,
};

/// An RGBA color
pub const ColorRGBA = struct {
    /// Red
    r: u8,
    /// Green
    g: u8,
    /// Blue
    b: u8,
    /// Alpha
    a: u8,
};

/// Represents a rendering context provided during each iteration
pub const RenderingContext = struct {
    /// The SDL window
    window: *c.SDL_Window,
    /// The SDL renderer
    renderer: *c.SDL_Renderer,
    /// Whether the rendered image has changes to be applied
    invalidated: bool,
};

/// The configuration for the SDL Window
pub const SDLWindowConfiguration = struct {
    /// The title of the window
    title: [:0]const u8,
    /// The background color of the window
    background: *const ColorRGBA,
    /// The aspect ratio of the window
    aspect_ratio: f32,
    /// The initial width
    initial_width: i32,
};

/// The input handlers of the client
pub const InputHandlers = struct {
    /// A handler for a click event
    click_event: fn (sdl_ctx: *RenderingContext, point: *const PointF) anyerror!void,
};

pub fn withSDLWindow(config: *const SDLWindowConfiguration, func: fn (*RenderingContext) anyerror!void, inputHandlers: *const InputHandlers) !void {
    listVideoDrivers();
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return printSDLErrorAndFail(error.SDLInitFailed);
    defer c.SDL_Quit();

    const projected_width = @as(f32, @floatFromInt(config.initial_width));

    // Create / Configure the window
    const window = c.SDL_CreateWindow(
        config.title,
        config.initial_width,
        @intFromFloat(projected_width * config.aspect_ratio),
        c.SDL_WINDOW_RESIZABLE,
    );

    if (window == null) return printSDLErrorAndFail(error.WindowCreationFailed);
    defer c.SDL_DestroyWindow(window);

    try sdlTry(c.SDL_SetWindowMinimumSize(window, 600, 600));
    try sdlTry(c.SDL_SetWindowAspectRatio(window, config.aspect_ratio, config.aspect_ratio));

    // Create / Configure the renderer
    const renderer = c.SDL_CreateRenderer(window, null);
    if (renderer == null) return printSDLErrorAndFail(error.RendererCreationFailed);
    defer c.SDL_DestroyRenderer(renderer);

    const background: ColorRGBA = config.*.background.*;
    var sdl_ctx: RenderingContext = .{ .renderer = renderer.?, .window = window.?, .invalidated = true };

    var event: c.SDL_Event = undefined;
    var running: bool = true;
    var current_scale: f32 = 1.0;
    var current_width: c_int = undefined;
    var current_height: c_int = undefined;
    var last_render: u64 = 0;

    // Render Loop
    while (running) {
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                // Default exit handler
                c.SDL_EVENT_QUIT => running = false,

                // Exit on Esc key
                c.SDL_EVENT_KEY_DOWN => {
                    if (event.key.key == c.SDLK_ESCAPE) running = false;
                },

                // Propagate clicks
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    if (event.button.button != c.SDL_BUTTON_LEFT) break;
                    const pt: PointF = .{ .x = (1 / current_scale) * event.button.x, .y = (1 / current_scale) * event.button.y };
                    try inputHandlers.click_event(&sdl_ctx, &pt);
                },

                else => {},
            }
        }

        const now = c.SDL_GetTicks();

        // Re-render at least once every 100ms
        if (now - last_render > 100)
            sdl_ctx.invalidated = true;

        try sdlTry(c.SDL_GetWindowSize(window, &current_width, &current_height));

        const next_scale: f32 = @as(f32, @floatFromInt(current_width)) / projected_width;
        if (next_scale != current_scale) {
            current_scale = next_scale;
            sdl_ctx.invalidated = true;
            try sdlTry(c.SDL_SetRenderScale(renderer, next_scale, next_scale));
        }

        // Skip re-rendering if nothing changed
        if (!sdl_ctx.invalidated) {
            c.SDL_Delay(16);
            continue;
        }

        sdl_ctx.invalidated = false;

        // Fill background
        try sdlTry(c.SDL_SetRenderDrawColor(renderer, background.r, background.g, background.b, background.a));
        try sdlTry(c.SDL_RenderClear(renderer));

        // Run client code
        try func(&sdl_ctx);

        // Render
        try sdlTry(c.SDL_RenderPresent(renderer));

        // ~ 60fps
        last_render = now;
        c.SDL_Delay(16);
    }
}

pub fn invalidate(sdl_ctx: *RenderingContext) void {
    sdl_ctx.invalidated = true;
}

/// Draws a line
pub fn drawLine(sdl_ctx: *RenderingContext, start: PointF, end: PointF, thickness: i32, color: *const ColorRGBA) !void {
    const renderer = sdl_ctx.*.renderer;

    // Simple line
    if (thickness == 1) {
        try sdlTry(c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));
        try sdlTry(c.SDL_RenderLine(renderer, start.x, start.y, end.x, end.y));
        return;
    }

    // Length of the line
    const f_len: f32 = math.sqrt(math.pow(f32, @abs(start.x - end.x), 2) + math.pow(f32, @abs(start.y - end.y), 2));

    // Angle
    const angle = math.atan2(end.y - start.y, end.x - start.x) * 180.0 / math.pi;

    // Prepare Texture (10x10 square)
    const tx = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_TARGET, 10, 10);
    defer c.SDL_DestroyTexture(tx);

    try sdlTry(c.SDL_SetRenderTarget(renderer, tx));
    try sdlTry(c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));
    try sdlTry(c.SDL_RenderClear(renderer));
    try sdlTry(c.SDL_SetRenderTarget(renderer, null));

    // Render
    const f_thickness: f32 = @floatFromInt(thickness);
    const piv_center: c.SDL_FPoint = .{ .x = 0.0, .y = f_thickness / 2 };
    const dstrect: c.SDL_FRect = .{ .x = start.x, .y = start.y - f_thickness / 2, .h = f_thickness, .w = f_len };

    try sdlTry(c.SDL_RenderTextureRotated(renderer, tx, null, &dstrect, angle, &piv_center, c.SDL_FLIP_NONE));
}

/// Draws a cricle
pub fn drawCircle(sdl_ctx: *RenderingContext, center: PointF, radius: f32, thickness: i32, color: *const ColorRGBA) !void {
    const renderer = sdl_ctx.*.renderer;

    // Create a texture of outer_radius x outer_radius
    const f_thickness = @as(f32, @floatFromInt(thickness));
    const outer_radius = radius + f_thickness / 2;
    const inner_radius = radius - f_thickness / 2;
    const tx_size: i32 = @intFromFloat(@ceil(outer_radius * 2));
    const p_center: PointF = .{ .x = outer_radius, .y = outer_radius };

    const tx = c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_TARGET, tx_size, tx_size);
    defer c.SDL_DestroyTexture(tx);

    try sdlTry(c.SDL_SetRenderTarget(renderer, tx));
    try sdlTry(c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a));

    // Draw the outer circle
    const y_outer_end = p_center.y + outer_radius;
    var y = p_center.y - outer_radius;

    while(y < y_outer_end) : (y += 1.0) {
        const dy = if (y > p_center.y) y - p_center.y else p_center.y - y;
        const dx = math.sqrt(outer_radius * outer_radius - dy * dy);

        const x_start = p_center.x - dx;
        const x_end = p_center.x + dx;

        try sdlTry(c.SDL_RenderLine(renderer, x_start, y, x_end, y));
    }

     // Alpha the inner circle
     try sdlTry(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0));

     const y_inner_end = p_center.y + inner_radius;
     y = p_center.y - inner_radius;

     while(y < y_inner_end) : (y += 1.0) {
        const dy = if (y > p_center.y) y - p_center.y else p_center.y - y;
        const dx = math.sqrt(inner_radius * inner_radius - dy * dy);

        const x_start = p_center.x - dx;
        const x_end = p_center.x + dx;

        try sdlTry(c.SDL_RenderLine(renderer, x_start, y, x_end, y));
    }

    // Reset the renderer
    try sdlTry(c.SDL_SetRenderTarget(renderer, null));

    // Render the texture to the screen
    const dstrect: c.SDL_FRect = .{ .x = center.x - outer_radius, .y = center.y - outer_radius, .h = outer_radius * 2, .w = outer_radius * 2 };
    try sdlTry(c.SDL_RenderTexture(renderer, tx, null, &dstrect));
}

/// List video drivers (for debugging purposes)
fn listVideoDrivers() void {
    c.SDL_Log("Available video drivers:");
    var i: c_int = c.SDL_GetNumVideoDrivers();
    while (i > 0) : (i -= 1) {
        c.SDL_Log("%s", c.SDL_GetVideoDriver(@as(c_int, i)));
    }
}

/// Prints the last SDL error and returns a generic SDLError
fn sdlTry(result: bool) !void {
    if (result) return;
    return printSDLErrorAndFail(error.SDLError);
}

/// Prints the last SDL error
fn printSDLError() void {
    c.SDL_Log("SDL error: %s", c.SDL_GetError());
}

/// Prints the last SDL error and returns the specified error
fn printSDLErrorAndFail(err: anyerror) !void {
    printSDLError();
    return err;
}
