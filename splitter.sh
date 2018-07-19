#!/bin/bash

file=$1; shift
slideshow_name="slideshow.pdf"
notes_name="notes.pdf"

if [[ ! -f $file ]]; then
  echo "Usage splitter.sh <full presentation pdf>"
  exit 0
fi

# render pdf with to get a doubled width pdf, slides | notes
# \setbeameroption{show notes on second screen}
gs -o $slideshow_name -sDEVICE=pdfwrite -c "[/CropBox [0 0 362.835 272.126]" -c " /PAGES pdfmark" -f $file
gs -o $notes_name -sDEVICE=pdfwrite -c "[/CropBox [362.835 0 725.669 272.126]" -c " /PAGES pdfmark" -f $file

echo "- your slides are in $slideshow_name"
echo "- your notes are in $notes_name"

