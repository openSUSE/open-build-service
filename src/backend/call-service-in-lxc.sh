#!/bin/bash

#FSDIR="/opt/obs/Source-Service.System"
FSDIR="/"
MOUNTDIR="/opt/obs/Source-Service-System.mounts"
TEMPDIR="/lxc.tmp"

INNEROUTDIR="$TEMPDIR/out"
INNERSRCDIR="$TEMPDIR/src"
INNERSCRIPT="$TEMPDIR/inner.sh"
RUNUSER="nobody"

#if ! grep -q "Linux version 2.6.32" /proc/version ; then
#  echo "ERROR: lxc seems to work only on linux kernel 2.6.32 atm"
#  exit 1
#fi

# prepare unique FS layer
MOUNTDIR="$MOUNTDIR/$$"
mkdir -p "$MOUNTDIR" || exit 1
mount --bind "$FSDIR" "$MOUNTDIR" || exit 1

mkdir -p "$MOUNTDIR$INNEROUTDIR" || exit 1
mount -t tmpfs /dev/tmp "$MOUNTDIR$INNEROUTDIR" || exit 1
mkdir -p "$MOUNTDIR/$INNEROUTDIR" "$MOUNTDIR/$INNERSRCDIR" || exit 1
chown $RUNUSER "$MOUNTDIR/$INNEROUTDIR"

# copy sources inside lxc root
#cp -a * "$MOUNTDIR/$INNERSRCDIR/" || exit 1
mount --bind "$PWD" "$MOUNTDIR/$INNERSRCDIR/"

echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"

MODE=""
WITH_NET=""
COMMAND=""

while [ $# -gt 0 ]; do
  if [ "$1" == "--outdir" ] ; then
     shift
     OUTDIR="$1"
  else
     COMMAND="$COMMAND \"${1/\"/_}\" "
     if [ -z "$MODE" ]; then
        case "$1" in
          */download_url|*/tar_scm|*/download_src_package)
            WITH_NET="1"
            ;;
        esac
     fi
  fi
  shift
done

#if [ "$WITH_NET" == "1" ] ; then
#  echo "rcnscd start" >> "$MOUNTDIR/$INNERSCRIPT"
#fi
echo -n "su $RUNUSER -c '" >> "$MOUNTDIR/$INNERSCRIPT"
echo "$COMMAND --outdir $INNEROUTDIR'" >> "$MOUNTDIR/$INNERSCRIPT"
chmod 0755 "$MOUNTDIR/$INNERSCRIPT"

# construct jail
LXC_CONF="/tmp/obs.service.$$"
echo "lxc.utsname = obs.service.$$" > $LXC_CONF
if [ "$WITH_NET" == "1" ] ; then
  mount -t proc proc $MOUNTDIR/proc
else
  echo "lxc.network.type = empty" >> $LXC_CONF
  echo "lxc.network.flags = up" >> $LXC_CONF
fi
#echo "lxc.pts = 1" >> $LXC_CONF
echo "lxc.tty = 1" >> $LXC_CONF
#echo "lxc.mount = /etc/fstab" >> $LXC_CONF
echo "lxc.rootfs = $MOUNTDIR" >> $LXC_CONF

lxc-info -n obs.service.jail.$$ >& /dev/null && lxc-destroy -n obs.service.jail.$$ >& /dev/null
RETURN="0"
lxc-create -n obs.service.jail.$$ -f $LXC_CONF >& /dev/null || RETURN="2"
rm -f $LXC_CONF

# run jailed process
lxc-start -n obs.service.jail.$$ "$INNERSCRIPT" || RETURN="2"

# destroy jail
lxc-destroy -n obs.service.jail.$$

# move out the result
if [ 0`find "$MOUNTDIR/$INNEROUTDIR" -type f | wc -l` -gt 0 ]; then
  mv "$MOUNTDIR/$INNEROUTDIR"/* "$OUTDIR/"
  for i in * ; do
    if [ ! -f "$MOUNTDIR/$INNEROUTDIR/$i" ]; then
      rm -f "$i"
    fi
  done
fi

# cleanup
if [ "$WITH_NET" == "1" ] ; then
  umount "$MOUNTDIR/proc"
fi
umount "$MOUNTDIR$INNERSRCDIR"
umount "$MOUNTDIR$INNEROUTDIR"
umount "$MOUNTDIR"
rmdir "$MOUNTDIR"

exit $RETURN

