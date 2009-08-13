#!/bin/bash

MOUNTDIR="/mnt/"

INNEROUTDIR="/tmp/out"
INNERSRCDIR="/tmp/src"
INNERSCRIPT="/tmp/inner.sh"

rm -rf $MOUNTDIR/tmp/*
mkdir -p "$MOUNTDIR/$INNEROUTDIR" "$MOUNTDIR/$INNERSRCDIR"

# copy sources inside lxc root
cp -a * "$MOUNTDIR/$INNERSRCDIR/"

echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"

MODE=""

while [ $# -gt 0 ]; do
  if [ "$1" == "--outdir" ] ; then
     shift
     OUTDIR="$1"
  else
     echo -n "\"${1/\"/_}\" " >> "$MOUNTDIR/$INNERSCRIPT"
     if [ -z "$MODE" ]; then
        case "$1" in
          download_url)
            MODE="withnet"
            ;;
          *)
            MODE="nonet"
            ;;
        esac
     fi
  fi
  shift
done

[ -z "$MODE" ] && exit 1

echo "--outdir $INNEROUTDIR" >> "$MOUNTDIR/$INNERSCRIPT"

chmod a+x "$MOUNTDIR/$INNERSCRIPT"
lxc-start -n "$MODE" "$INNERSCRIPT" || exit 1

# move out the result
mv "$MOUNTDIR/$INNEROUTDIR"/* "$OUTDIR/"

