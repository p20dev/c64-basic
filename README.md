# C64 BASIC Collection

Ten small, polished programs for the Commodore 64, written entirely in stock
Commodore BASIC V2. The collection mixes arcade action, puzzles, simulations,
creative tools, sound, and visual effects. No cartridge, BASIC extension, or
machine-language payload is required.

## Programs

| Program | Type | Controls | Description | Play online |
| --- | --- | --- | --- | --- |
| [Meteor Dodge](meteor-dodge/meteor-dodge.bas) | Arcade | `A`, `D`, `Q` | Dodge falling meteors and build your score. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#meteor-dodge) |
| [Code Breaker](code-breaker/code-breaker.bas) | Logic | Digits, `Q` | Deduce a four-digit secret in ten guesses. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#code-breaker) |
| [Submarine Hunt](submarine-hunt/submarine-hunt.bas) | Strategy | Coordinates, `Q` | Find three hidden submarines with limited sonar shots. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#submarine-hunt) |
| [Lunar Lander](lunar-lander/lunar-lander.bas) | Simulation | `0`-`9`, `Q` | Choose engine burns and touch down gently. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#lunar-lander) |
| [Memory Matrix](memory-matrix/memory-matrix.bas) | Memory | `1`-`4`, `Q` | Repeat a growing sequence of flashing quadrants. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#memory-matrix) |
| [Robot Maze](robot-maze/robot-maze.bas) | Puzzle | `W`, `A`, `S`, `D`, `Q` | Navigate a freshly generated maze to its exit. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#robot-maze) |
| [Music Box](music-box/music-box.bas) | Music | `A`-`K`, `1`-`3`, `Q` | Play the SID chip as a small computer keyboard. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#music-box) |
| [Pixel Painter](pixel-painter/pixel-painter.bas) | Creative | Cursor keys, Space, `C`, `Q` | Draw character-cell pictures on the screen. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#pixel-painter) |
| [Stock Trader](stock-trader/stock-trader.bas) | Simulation | `B`, `S`, `W`, `Q` | Trade a volatile stock over twenty market days. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#stock-trader) |
| [Starfield](starfield/starfield.bas) | Demo | `1`-`3`, `Q` | Watch and control a layered animated starfield. | [Run program](https://htmlpreview.github.io/?https://git.p20.dev/christian/c64-basic/raw/branch/main/runner.html#starfield) |

## Running the programs

Click a **Run program** link in the table to launch that program directly in a
browser-based VICE x64sc emulator powered by WebAssembly. The runner downloads
the emulator from the EmulatorJS CDN; the program itself is embedded in the
repository's runner, so no file picker or manual loading is required. Click the
emulator once to give it keyboard focus and enable audio.

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

