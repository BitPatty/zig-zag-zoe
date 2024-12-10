const SDL = @import("./sdl.zig");

const Cell = struct { x1: f32, y1: f32, x2: f32, y2: f32 };

const GRID_SIZE: u32 = 600;
const GRID_SIZE_FLOAT: f32 = @floatFromInt(GRID_SIZE);
const CELL_SIZE: f32 = GRID_SIZE_FLOAT / 3.0;

const Cells = [9]Cell{
    // Top Left
    .{ .x1 = 0, .y1 = 0, .x2 = CELL_SIZE, .y2 = CELL_SIZE },
    // Top Center
    .{ .x1 = CELL_SIZE, .y1 = 0, .x2 = 2 * CELL_SIZE, .y2 = CELL_SIZE },
    // Top Right
    .{ .x1 = 2 * CELL_SIZE, .y1 = 0, .x2 = 3 * CELL_SIZE, .y2 = CELL_SIZE },
    // Middle Left
    .{ .x1 = 0, .y1 = CELL_SIZE, .x2 = CELL_SIZE, .y2 = 2 * CELL_SIZE },
    // Middle Center
    .{ .x1 = CELL_SIZE, .y1 = CELL_SIZE, .x2 = 2 * CELL_SIZE, .y2 = 2 * CELL_SIZE },
    // Middle Right
    .{ .x1 = 2 * CELL_SIZE, .y1 = CELL_SIZE, .x2 = 3 * CELL_SIZE, .y2 = 2 * CELL_SIZE },
    // Bottom Left
    .{ .x1 = 0, .y1 = 2 * CELL_SIZE, .x2 = CELL_SIZE, .y2 = 3 * CELL_SIZE },
    // Bottom Center
    .{ .x1 = CELL_SIZE, .y1 = 2 * CELL_SIZE, .x2 = 2 * CELL_SIZE, .y2 = 3 * CELL_SIZE },
    // Bottom Right
    .{ .x1 = 2 * CELL_SIZE, .y1 = 2 * CELL_SIZE, .x2 = 3 * CELL_SIZE, .y2 = 3 * CELL_SIZE },
};

// Game States
const Player = enum {
    X,
    O,
};

const CellState = enum {
    PLAYER_X,
    PLAYER_O,
    EMPTY,
};

var CurrentPlayer: Player = Player.X;

var CellStates = [9]CellState{
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
    CellState.EMPTY,
};

const Winner = enum { PLAYER_X, PLAYER_O, TIE, NONE };

// Colors
const LIGHT_GRAY: *const SDL.ColorRGBA = &.{ .r = 130, .g = 130, .b = 130, .a = 255 };
const DARK_GRAY: *const SDL.ColorRGBA = &.{ .r = 30, .g = 30, .b = 30, .a = 255 };
const RED: *const SDL.ColorRGBA = &.{ .r = 255, .g = 0, .b = 0, .a = 255 };
const BLUE: *const SDL.ColorRGBA = &.{ .r = 0, .g = 0, .b = 255, .a = 255 };

/// Main Entrypoint
pub fn main() !void {
    const window_cfg: SDL.SDLWindowConfiguration = .{ .title = "Tic Tac Toe", .background = DARK_GRAY, .aspect_ratio = 1.0, .initial_width = 600 };
    const event_handlers: SDL.InputHandlers = .{ .click_event = processClick };
    try SDL.withSDLWindow(&window_cfg, renderGame, &event_handlers);
}

/// Processes a click in the game screen
fn processClick(sdl_ctx: *SDL.RenderingContext, pt: *const SDL.PointF) !void {
    const winner = getWinner();

    if (winner != Winner.NONE) {
        resetGame();
        SDL.invalidate(sdl_ctx);
        return;
    }

    const cell_index = getCellIndexAtCoordinate(pt.x, pt.y);
    if (cell_index == null) return;

    const cell_state = try getCellStateAtIndex(cell_index.?);
    if (cell_state != CellState.EMPTY) return;

    if (CurrentPlayer == Player.X) {
        CellStates[cell_index.?] = CellState.PLAYER_X;
        CurrentPlayer = Player.O;
    } else {
        CellStates[cell_index.?] = CellState.PLAYER_O;
        CurrentPlayer = Player.X;
    }

    SDL.invalidate(sdl_ctx);
}

/// Renders the game
fn renderGame(sdl_ctx: *SDL.RenderingContext) !void {
    const winner = getWinner();

    switch (winner) {
        Winner.PLAYER_X => {
            try fillWindowWithX(sdl_ctx);
            return;
        },

        Winner.PLAYER_O => {
            try fillWindowWithO(sdl_ctx);
            return;
        },

        Winner.TIE => {
            try fillWindowWithX(sdl_ctx);
            try fillWindowWithO(sdl_ctx);
            return;
        },

        else => {},
    }

    try printGrid(sdl_ctx);

    for (CellStates, 0..) |cell_state, i| {
        if (cell_state == CellState.EMPTY) continue;
        if (cell_state == CellState.PLAYER_X) try renderXToCell(sdl_ctx, @intCast(i));
        if (cell_state == CellState.PLAYER_O) try renderOToCell(sdl_ctx, @intCast(i));
    }
}

/// Renders a fullscreen O to the game
fn fillWindowWithO(sdl_ctx: *SDL.RenderingContext) !void {
    const pad = GRID_SIZE_FLOAT / 5;

    try SDL.drawCircle(sdl_ctx, .{ .x = GRID_SIZE_FLOAT / 2, .y = GRID_SIZE_FLOAT / 2 }, (GRID_SIZE_FLOAT - pad - pad) / 2, 10, BLUE);
}

/// Renders a fullscreen X to the game
fn fillWindowWithX(sdl_ctx: *SDL.RenderingContext) !void {
    const pad = GRID_SIZE_FLOAT / 5;

    try SDL.drawLine(sdl_ctx, .{ .x = pad, .y = pad }, .{ .x = GRID_SIZE_FLOAT - pad, .y = GRID_SIZE_FLOAT - pad }, 10, RED);
    try SDL.drawLine(sdl_ctx, .{ .x = pad, .y = GRID_SIZE_FLOAT - pad }, .{ .x = GRID_SIZE_FLOAT - pad, .y = pad }, 10, RED);
}

/// Prints an O into the specified cell
fn renderOToCell(sdl_ctx: *SDL.RenderingContext, cell_idx: u8) !void {
    const t_cell = try getCellAtIndex(cell_idx);
    const p: SDL.PointF = .{ .x = t_cell.x1 + (CELL_SIZE / 2), .y = t_cell.y1 + (CELL_SIZE / 2) };
    const r = (CELL_SIZE - (2 * CELL_SIZE / 5)) / 2;
    try SDL.drawCircle(sdl_ctx, p, r, 10, BLUE);
}

/// Prints an X into the specified cell
fn renderXToCell(sdl_ctx: *SDL.RenderingContext, cell_idx: u8) !void {
    const t_cell = try getCellAtIndex(cell_idx);
    const pad = CELL_SIZE / 5;
    try SDL.drawLine(sdl_ctx, .{ .x = t_cell.x1 + pad, .y = t_cell.y1 + pad }, .{ .x = t_cell.x2 - pad, .y = t_cell.y2 - pad }, 10, RED);
    try SDL.drawLine(sdl_ctx, .{ .x = t_cell.x1 + pad, .y = t_cell.y2 - pad }, .{ .x = t_cell.x2 - pad, .y = t_cell.y1 + pad }, 10, RED);
}

/// Resets the game
fn resetGame() void {
    for (CellStates, 0..) |_, i|
        CellStates[i] = CellState.EMPTY;
}

/// Gets the current winner of the game
fn getWinner() Winner {
    if (isWinConditionMet(CellState.PLAYER_X)) return Winner.PLAYER_X;
    if (isWinConditionMet(CellState.PLAYER_O)) return Winner.PLAYER_O;

    for (CellStates) |cell_state|
        if (cell_state == CellState.EMPTY) return Winner.NONE;

    return Winner.TIE;
}

/// Checks whether the win condition is met for the specified cell state
fn isWinConditionMet(player: CellState) bool {
    // Winning lines: rows, columns, and diagonals
    const winning_lines = comptime [_][3]u8{
        // Rows
        .{ 0, 1, 2 },
        .{ 3, 4, 5 },
        .{ 6, 7, 8 },
        // Columns
        .{ 0, 3, 6 },
        .{ 1, 4, 7 },
        .{ 2, 5, 8 },
        // Diagonals
        .{ 0, 4, 8 },
        .{ 2, 4, 6 },
    };

    for (winning_lines) |line| {
        if (CellStates[line[0]] == player and
            CellStates[line[1]] == player and
            CellStates[line[2]] == player)
        {
            return true; // Win condition met
        }
    }

    return false; // No winning line found
}
/// Gets the cell index for the specified coordinate
/// Returns null if none was found
fn getCellIndexAtCoordinate(x: f32, y: f32) ?u8 {
    for (Cells, 0..) |cell, i| {
        if (cell.x1 >= x) continue;
        if (cell.x2 <= x) continue;
        if (cell.y1 >= y) continue;
        if (cell.y2 <= y) continue;

        return @intCast(i);
    }

    return null;
}

/// Gets the current cell state at the index
fn getCellStateAtIndex(cell_idx: u8) !CellState {
    if (cell_idx < 0) return error.OutOfBounds;
    if (cell_idx > Cells.len - 1) return error.OutOfBonds;
    return CellStates[cell_idx];
}

/// Gets the cell at the specified index
fn getCellAtIndex(cell_idx: u8) !Cell {
    if (cell_idx < 0) return error.OutOfBounds;
    if (cell_idx > Cells.len - 1) return error.OutOfBounds;
    return Cells[cell_idx];
}

/// Prints the grid
fn printGrid(sdl_ctx: *SDL.RenderingContext) !void {
    for (Cells) |cell| {
        // Left border
        try SDL.drawLine(sdl_ctx, .{ .x = cell.x1, .y = cell.y1 }, .{ .x = cell.x1, .y = cell.y2 }, 5, LIGHT_GRAY);
        // Right border
        try SDL.drawLine(sdl_ctx, .{ .x = cell.x2, .y = cell.y1 }, .{ .x = cell.x2, .y = cell.y2 }, 5, LIGHT_GRAY);
        // Top border
        try SDL.drawLine(sdl_ctx, .{ .x = cell.x1, .y = cell.y1 }, .{ .x = cell.x2, .y = cell.y1 }, 5, LIGHT_GRAY);
        // Bottom border
        try SDL.drawLine(sdl_ctx, .{ .x = cell.x1, .y = cell.y2 }, .{ .x = cell.x2, .y = cell.y2 }, 5, LIGHT_GRAY);
    }
}
