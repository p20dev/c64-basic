# C64 BASIC Collection

Ten small, polished programs for the Commodore 64, written entirely in stock
Commodore BASIC V2. The collection mixes arcade action, puzzles, simulations,
creative tools, sound, and visual effects. No cartridge, BASIC extension, or
machine-language payload is required.

## Programs

| Program | Type | Controls | Description |
| --- | --- | --- | --- |
| [Meteor Dodge](meteor-dodge/meteor-dodge.bas) | Arcade | `A`, `D`, `Q` | Dodge falling meteors and build your score. |
| [Code Breaker](code-breaker/code-breaker.bas) | Logic | Digits, `Q` | Deduce a four-digit secret in ten guesses. |
| [Submarine Hunt](submarine-hunt/submarine-hunt.bas) | Strategy | Coordinates, `Q` | Find three hidden submarines with limited sonar shots. |
| [Lunar Lander](lunar-lander/lunar-lander.bas) | Simulation | `0`-`9`, `Q` | Choose engine burns and touch down gently. |
| [Memory Matrix](memory-matrix/memory-matrix.bas) | Memory | `1`-`4`, `Q` | Repeat a growing sequence of flashing quadrants. |
| [Robot Maze](robot-maze/robot-maze.bas) | Puzzle | `W`, `A`, `S`, `D`, `Q` | Navigate a freshly generated maze to its exit. |
| [Music Box](music-box/music-box.bas) | Music | `A`-`K`, `1`-`3`, `Q` | Play the SID chip as a small computer keyboard. |
| [Pixel Painter](pixel-painter/pixel-painter.bas) | Creative | Cursor keys, Space, `C`, `Q` | Draw character-cell pictures on the screen. |
| [Stock Trader](stock-trader/stock-trader.bas) | Simulation | `B`, `S`, `W`, `Q` | Trade a volatile stock over twenty market days. |
| [Starfield](starfield/starfield.bas) | Demo | `1`-`3`, `Q` | Watch and control a layered animated starfield. |

## Running the programs

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

