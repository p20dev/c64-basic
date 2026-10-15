#!/bin/sh
set -eu

for source in \
  sprite-playground/sprite-playground.asm \
  raster-bars/raster-bars.asm \
  sid-arpeggiator/sid-arpeggiator.asm
do
  output="${source%.asm}.prg"
  echo "Assembling $source -> $output"
  acme --format cbm --outfile "$output" "$source"
done
