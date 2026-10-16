#!/bin/sh
set -eu

for source in \
  sprite-playground/sprite-playground.asm \
  raster-bars/raster-bars.asm \
  sid-arpeggiator/sid-arpeggiator.asm \
  paddle-ball/paddle-ball.asm \
  smooth-scroller/smooth-scroller.asm \
  fireworks/fireworks.asm \
  jiffy-clock/jiffy-clock.asm \
  typing-sprint/typing-sprint.asm \
  petscii-aquarium/petscii-aquarium.asm \
  fifteen-puzzle/fifteen-puzzle.asm \
  plasma-grid/plasma-grid.asm \
  neon-rift/neon-rift.asm
do
  output="${source%.asm}.prg"
  echo "Assembling $source -> $output"
  acme --format cbm --outfile "$output" "$source"
done
