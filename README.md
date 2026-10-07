# C64 BASIC Collection

Ten small, polished programs for the Commodore 64, written entirely in stock
Commodore BASIC V2. The collection mixes arcade action, puzzles, simulations,
creative tools, sound, and visual effects. No cartridge, BASIC extension, or
machine-language payload is required.

## Programs

| Program | Type | Controls | Description | Run locally |
| --- | --- | --- | --- | --- |
| [Meteor Dodge](meteor-dodge/meteor-dodge.bas) | Arcade | `A`, `D`, `Q` | Dodge falling meteors and build your score. | [Run program](http://localhost:8134/program/meteor-dodge) |
| [Code Breaker](code-breaker/code-breaker.bas) | Logic | `0`-`9`, `Q` | Deduce a four-digit secret in ten guesses. | [Run program](http://localhost:8134/program/code-breaker) |
| [Submarine Hunt](submarine-hunt/submarine-hunt.bas) | Strategy | Row, Column, `Q` | Find three hidden submarines with limited sonar shots. | [Run program](http://localhost:8134/program/submarine-hunt) |
| [Lunar Lander](lunar-lander/lunar-lander.bas) | Simulation | `0`-`9`, `Q` | Choose engine burns and touch down gently. | [Run program](http://localhost:8134/program/lunar-lander) |
| [Memory Matrix](memory-matrix/memory-matrix.bas) | Memory | `1`, `2`, `3`, `4`, `Q` | Repeat a growing sequence of flashing quadrants. | [Run program](http://localhost:8134/program/memory-matrix) |
| [Robot Maze](robot-maze/robot-maze.bas) | Puzzle | `W`, `A`, `S`, `D`, `Q` | Navigate a freshly generated maze to its exit. | [Run program](http://localhost:8134/program/robot-maze) |
| [Music Box](music-box/music-box.bas) | Music | `A`-`K`, `1`, `2`, `3`, `Q` | Play the SID chip as a small computer keyboard. | [Run program](http://localhost:8134/program/music-box) |
| [Pixel Painter](pixel-painter/pixel-painter.bas) | Creative | Cursor keys, Space, `C`, `Q` | Draw character-cell pictures on the screen. | [Run program](http://localhost:8134/program/pixel-painter) |
| [Stock Trader](stock-trader/stock-trader.bas) | Simulation | `B`, `S`, `W`, `Q` | Trade a volatile stock over twenty market days. | [Run program](http://localhost:8134/program/stock-trader) |
| [Starfield](starfield/starfield.bas) | Demo | `1`, `2`, `3`, `Q` | Watch and control a layered animated starfield. | [Run program](http://localhost:8134/program/starfield) |

## Running the programs

Start the local browser app with Docker Compose:

```text
docker compose up --build -d
```

Open [http://localhost:8134](http://localhost:8134), or click a **Run program**
link in the table. The app runs the VICE x64sc core through WebAssembly and
downloads the selected PRG through its own backend, avoiding browser CORS
restrictions. Click inside the emulator to enable keyboard input and sound.
Direct keyboard input is enabled by default, mouse locking is disabled, and
moving the pointer anywhere over the emulator reveals its control bar.

Docker Compose mounts this repository read-only at `/programs`, and the app
serves PRG files from that local mount. There is no runtime dependency on the
Git server and no browser CORS boundary. Add a program to `programs.json` and
place its PRG in the referenced path; it appears after clicking **Refresh list**
without rebuilding the image. The default host port is configured as `8134` in
`.env`.

Each directory contains an editable, line-numbered `.bas` listing and a matching
tokenized `.prg` file. The PRGs use the normal C64 BASIC load address, `$0801`.

On a Commodore 64, transfer a PRG to disk or another supported medium, then use:

```text
LOAD"METEOR-DODGE.PRG",8
RUN
```

Substitute the filename and device number as needed. In VICE or another C64
emulator, drag a PRG into the emulator window or use its autostart command.

## Source format

The `.bas` files are plain ASCII for comfortable reading and editing on a modern
computer. They use uppercase BASIC V2 keywords and avoid embedded control-code
glyphs. Their corresponding `.prg` files contain the tokenized PETSCII program
that the C64 loads directly.

All programs are self-contained and designed for an ordinary PAL or NTSC
Commodore 64. Randomized programs seed BASIC's random-number generator from the
machine clock, so every session is different.

