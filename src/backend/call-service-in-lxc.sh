#!/bin/bash

FSDIR="/opt/obs/SourceServiceSystem"
MOUNTDIR="/opt/obs/SourceServiceSystem.mounts"
TEMPDIR="/tmp"

INNEROUTDIR="$TEMPDIR/out"
INNERSRCDIR="$TEMPDIR/src"
INNERSCRIPT="$TEMPDIR/inner.sh"
RUNUSER="nobody"

# prepare unique FS layer
MOUNTDIR="$MOUNTDIR/$$"
mkdir -p "$MOUNTDIR" || exit 1
mount --bind "$FSDIR" "$MOUNTDIR" || exit 1
mount -t tmpfs /dev/tmp "$MOUNTDIR$TEMPDIR" || exit 1
mkdir -p "$MOUNTDIR/$INNEROUTDIR" "$MOUNTDIR/$INNERSRCDIR" || exit 1
chown $RUNUSER "$MOUNTDIR/$INNEROUTDIR"

# copy sources inside lxc root
cp -a * "$MOUNTDIR/$INNERSRCDIR/" || exit 1

echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"

MODE=""
WITH_NET=""

echo -n "su $RUNUSER -c '" >> "$MOUNTDIR/$INNERSCRIPT"
while [ $# -gt 0 ]; do
  if [ "$1" == "--outdir" ] ; then
     shift
     OUTDIR="$1"
  else
     echo -n "\"${1/\"/_}\" " >> "$MOUNTDIR/$INNERSCRIPT"
     if [ -z "$MODE" ]; then
        case "$1" in
          */download_url)
            WITH_NET="1"
            ;;
        esac
     fi
  fi
  shift
done
echo "--outdir $INNEROUTDIR'" >> "$MOUNTDIR/$INNERSCRIPT"
chmod a+x "$MOUNTDIR/$INNERSCRIPT"

# construct jail
LXC_CONF="/tmp/obs.service.$$"
echo "lxc.utsname = obs.service.$$" > $LXC_CONF
if [ "$WITH_NET" != "1" ] ; then
  echo "lxc.network.type = empty" >> $LXC_CONF
  echo "lxc.network.flags = up" >> $LXC_CONF
fi
#echo "lxc.pts = 1" >> $LXC_CONF
#echo "lxc.mount = /etc/fstab" >> $LXC_CONF
echo "lxc.rootfs = $MOUNTDIR" >> $LXC_CONF
# FIXME: make a check for an existing jail and die
lxc-destroy -n obs.service.jail.$$
lxc-create -n obs.service.jail.$$ -f $LXC_CONF || exit 1
rm -f $LXC_CONF

# run jailed process
lxc-start -n obs.service.jail.$$ "$INNERSCRIPT" || exit 1

# destroy jail
lxc-destroy -n obs.service.jail.$$

# move out the result
mv "$MOUNTDIR/$INNEROUTDIR"/* "$OUTDIR/"

# cleanup
umount "$MOUNTDIR$TEMPDIR"
umount "$MOUNTDIR"
rmdir "$MOUNTDIR"

