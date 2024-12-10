# Tic Tac Toe

Inspired by [tsoding](https://www.youtube.com/watch?v=gCVMkKgs3uQ), this repository contains an implementation of Tic Tac Toe using [Zig](https://ziglang.org/) and [SDL3](https://wiki.libsdl.org/SDL3/FrontPage). I used this to continue learning the basics of zig as well as SDL3.

## Preview

![Preview](./preview.png)

## Features
- Playable Tic Tac Toe game with a simple interface.
- Supports Player X and Player O turns.
- Detects win conditions and ties.
- Uses Vulkan for rendering via SDL3.


## Building

The project was implemented using zig 0.13.0 and libSDL3.so.0.1.7. The SDL wrapper is configured to use `vulkan` for rendering, it can be adjusted if necessary (see `src/sdl.zig`). As the time of this writing SDL3 has not been released yet and oftentimes must be built ["The Unix Way"](https://wiki.libsdl.org/SDL3/Installation).

The project can be built as usual as follows:

```sh
zig build
```
## Running the game

To run the game simply append `run` to the build command:

```sh
zig build run
```