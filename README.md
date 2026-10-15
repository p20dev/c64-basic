# C64 Program Collection

Twenty-three small, polished programs for the Commodore 64, written in stock
Commodore BASIC V2 and 6502 machine code. The collection mixes arcade action,
puzzles, simulations, creative tools, sound, and visual effects. Every entry is
self-contained and runs on an ordinary PAL or NTSC C64 without a cartridge or
BASIC extension.

## Programs

| Program | Category | Language | Controls | Description | Source | Run locally |
| --- | --- | --- | --- | --- | --- | --- |
| Meteor Dodge | Arcade | BASIC | `A`, `D`, `Q` | Dodge falling meteors and build your score. | [BAS](meteor-dodge/meteor-dodge.bas) | [Run](http://localhost:8134/program/meteor-dodge) |
| Code Breaker | Logic | BASIC | `0`-`9`, Return, `Q` | Deduce a four-digit secret in ten guesses. | [BAS](code-breaker/code-breaker.bas) | [Run](http://localhost:8134/program/code-breaker) |
| Submarine Hunt | Strategy | BASIC | Row, Column, Return | Find three hidden submarines with limited sonar shots. | [BAS](submarine-hunt/submarine-hunt.bas) | [Run](http://localhost:8134/program/submarine-hunt) |
| Lunar Lander | Simulation | BASIC | `0`-`9`, Return, `-1` | Choose engine burns and touch down gently. | [BAS](lunar-lander/lunar-lander.bas) | [Run](http://localhost:8134/program/lunar-lander) |
| Memory Matrix | Memory | BASIC | `1`, `2`, `3`, `4`, `Q` | Repeat a growing sequence of flashing quadrants. | [BAS](memory-matrix/memory-matrix.bas) | [Run](http://localhost:8134/program/memory-matrix) |
| Robot Maze | Puzzle | BASIC | `W`, `A`, `S`, `D`, `Q` | Navigate a freshly generated maze to its exit. | [BAS](robot-maze/robot-maze.bas) | [Run](http://localhost:8134/program/robot-maze) |
| Music Box | Music | BASIC | `A`-`K`, `1`, `2`, `3`, `Q` | Play the SID chip as a small computer keyboard. | [BAS](music-box/music-box.bas) | [Run](http://localhost:8134/program/music-box) |
| Pixel Painter | Creative | BASIC | Cursor keys, Space, `C`, `Q` | Draw character-cell pictures on the screen. | [BAS](pixel-painter/pixel-painter.bas) | [Run](http://localhost:8134/program/pixel-painter) |
| Stock Trader | Simulation | BASIC | `B`, `S`, `W`, `Q` | Trade a volatile stock over twenty market days. | [BAS](stock-trader/stock-trader.bas) | [Run](http://localhost:8134/program/stock-trader) |
| Starfield | Demo | BASIC | `1`, `2`, `3`, `Q` | Watch and control a layered animated starfield. | [BAS](starfield/starfield.bas) | [Run](http://localhost:8134/program/starfield) |
| Snake Trail | Arcade | BASIC | `W`, `A`, `S`, `D`, `Q` | Guide a growing snake through a field of food and danger. | [BAS](snake-trail/snake-trail.bas) | [Run](http://localhost:8134/program/snake-trail) |
| Dice Poker | Dice | BASIC | `1`-`5`, Return, `Q` | Keep your best dice and chase a winning poker combination. | [BAS](dice-poker/dice-poker.bas) | [Run](http://localhost:8134/program/dice-poker) |
| Word Scramble | Word | BASIC | `A`-`Z`, Return, `Q` | Unscramble five computer-themed words from helpful clues. | [BAS](word-scramble/word-scramble.bas) | [Run](http://localhost:8134/program/word-scramble) |
| Nim Challenge | Strategy | BASIC | `1`, `2`, `3`, `0` | Outthink the computer in the classic game of twenty-one sticks. | [BAS](nim-challenge/nim-challenge.bas) | [Run](http://localhost:8134/program/nim-challenge) |
| Reaction Timer | Reflex | BASIC | Any key, `Q` | Test your reactions across five unpredictable timed rounds. | [BAS](reaction-timer/reaction-timer.bas) | [Run](http://localhost:8134/program/reaction-timer) |
| Morse Trainer | Educational | BASIC | `A`-`Z`, Return, `Q` | Learn Morse letters by reading and hearing their signals. | [BAS](morse-trainer/morse-trainer.bas) | [Run](http://localhost:8134/program/morse-trainer) |
| Kaleidoscope | Demo | BASIC | Space, `C`, `Q` | Grow colorful symmetrical patterns across the character screen. | [BAS](kaleidoscope/kaleidoscope.bas) | [Run](http://localhost:8134/program/kaleidoscope) |
| World Quiz | Trivia | BASIC | `1`, `2`, `3`, `Q` | Take a seven-stop tour of world geography and landmarks. | [BAS](world-quiz/world-quiz.bas) | [Run](http://localhost:8134/program/world-quiz) |
| Life Lab | Simulation | BASIC | Space, `R`, `Q` | Observe generations of Conway's cellular automaton evolve. | [BAS](life-lab/life-lab.bas) | [Run](http://localhost:8134/program/life-lab) |
| Cipher Wheel | Utility | BASIC | `E`, `D`, `N`, `Q` | Encode and decode secret messages with a Caesar shift. | [BAS](cipher-wheel/cipher-wheel.bas) | [Run](http://localhost:8134/program/cipher-wheel) |
| Sprite Playground | Creative | Machine Code | `W`, `A`, `S`, `D`, `C`, `Q` | Move and recolor a hardware sprite in a responsive VIC-II playground. | [ASM](sprite-playground/sprite-playground.asm) | [Run](http://localhost:8134/program/sprite-playground) |
| Raster Bars | Demo | Machine Code | `1`, `2`, `3`, `C`, `Q` | Paint animated bands of color with cycle-aware VIC-II raster timing. | [ASM](raster-bars/raster-bars.asm) | [Run](http://localhost:8134/program/raster-bars) |
| SID Arpeggiator | Music | Machine Code | `A`-`K`, `1`-`3`, `+`, `-`, Space, `Q` | Shape a looping SID arpeggio with notes, waveforms, and tempo controls. | [ASM](sid-arpeggiator/sid-arpeggiator.asm) | [Run](http://localhost:8134/program/sid-arpeggiator) |

## Running the programs

Start the local browser app with Docker Compose:

```text
docker compose up --build -d
```

Open [http://localhost:8134](http://localhost:8134), or use a **Run** link in
the table. The app runs the VICE x64sc core through WebAssembly and downloads
the selected PRG through its own backend. Click inside the emulator to enable
keyboard input and sound. Direct keyboard input is enabled by default, mouse
locking is disabled, and moving the pointer anywhere over the emulator reveals
its control bar.

The repository is mounted read-only at `/programs`. Add a manifest entry and
its source and PRG files, then click **Refresh**; the app does not need to be
rebuilt. The default host port is configured as `8134` in `.env`.

On a Commodore 64, transfer a PRG to disk or another supported medium, then use:

```text
LOAD"METEOR-DODGE.PRG",8
RUN
```

Substitute the filename and device number as needed. The machine-code PRGs
include a small BASIC `SYS` launcher, so the same `RUN` command starts them.

## Building machine-code programs

The assembly sources use ACME syntax. Build every machine-code PRG with the
isolated tools profile; no local assembler installation is required:

```text
docker compose --profile tools run --rm assembler
```

The tools profile is opt-in and is not started by the normal app command.

## Source format

Each program directory contains a loadable `.prg` and its readable source:

- BASIC programs use line-numbered, uppercase `.bas` files compatible with
  stock Commodore BASIC V2. Their PRGs are tokenized at the normal `$0801`
  BASIC load address.
- Machine-code programs use commented ACME `.asm` files. Their PRGs also load
  at `$0801`, where a short BASIC line starts the 6502 code with `SYS`.

All programs are self-contained and designed for ordinary PAL and NTSC C64
hardware as well as VICE-compatible emulators.
