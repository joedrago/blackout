#!/bin/sh

brew install webkit2png

BASEDIR=$(dirname $0)
cd $BASEDIR
echo Working dir: `pwd`

for PAGE in page1 page2; do
  webkit2png -z 0.5 -F -W 1280 -H 720 --selector "#$PAGE" -o $PAGE index.html
  mv $PAGE-full.png ../res/raw/howto$PAGE.png
done
