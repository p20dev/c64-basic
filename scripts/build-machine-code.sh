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
  neon-rift/neon-rift.asm \
  infinite-road/infinite-road.asm \
  haunted-night/haunted-night.asm \
  happy-birthday-beca/happy-birthday-beca.asm \
  tv-fireplace/tv-fireplace.asm \
  ripple-chamber/ripple-chamber.asm \
  cat-vibing/cat-vibing.asm \
  rickroll/rickroll.asm \
  orbital-reverie/orbital-reverie.asm \
  prism-sanctuary/prism-sanctuary.asm \
  midnight-aurora/midnight-aurora.asm \
  solar-crown/solar-crown.asm \
  cloud-nine/cloud-nine.asm \
  sunset-rally/sunset-rally.asm
do
  output="${source%.asm}.prg"
  echo "Assembling $source -> $output"
  acme --format cbm --outfile "$output" "$source"
done
