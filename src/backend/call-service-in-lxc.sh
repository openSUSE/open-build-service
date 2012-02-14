#!/bin/bash

#FSDIR="/opt/obs/SourceServiceSystem"
FSDIR="/"
MOUNTDIR="/opt/obs/SourceServiceSystem.mounts/"
TEMPDIR="/lxc.tmp.$$"

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

mkdir -p "$MOUNTDIR/$INNERSRCDIR" || exit 1
chown -R $RUNUSER "$MOUNTDIR/$INNERSRCDIR" .

# copy sources inside lxc root
#cp -a * "$MOUNTDIR/$INNERSRCDIR/" || exit 1
mount --bind "$PWD" "$MOUNTDIR/$INNERSRCDIR/"

echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"

WITH_NET="0"
COMMAND="$1"
shift
case "$COMMAND" in
  */download_url|*/tar_scm|*/download_src_package|*/update_source|*/download_files)
    WITH_NET="1"
    ;;
esac

while [ $# -gt 0 ]; do
  if [ "$1" == "--outdir" ] ; then
     shift
     OUTDIR="$1"
  else
     COMMAND="$COMMAND '${1//\'/_}'"
  fi
  shift
done

if [ -z "$OUTDIR" ] ; then
  echo "ERROR: no outdir given"
  exit 1
fi
mkdir -p "$MOUNTDIR$INNEROUTDIR" || exit 1
mount --bind "$OUTDIR" "$MOUNTDIR$INNEROUTDIR" || exit 1
chown -R $RUNUSER "$MOUNTDIR/$INNEROUTDIR"

#if [ "$WITH_NET" == "1" ] ; then
#  echo "rcnscd start" >> "$MOUNTDIR/$INNERSCRIPT"
#fi
echo -n "su $RUNUSER -s ${INNERSCRIPT}.command" >> "$MOUNTDIR/$INNERSCRIPT"
echo "#!/bin/bash"                         >  "$MOUNTDIR/${INNERSCRIPT}.command"
echo "${COMMAND[@]} --outdir $INNEROUTDIR" >> "$MOUNTDIR/${INNERSCRIPT}.command"
chmod 0755 "$MOUNTDIR/$INNERSCRIPT" "$MOUNTDIR/${INNERSCRIPT}.command"

# construct jail
LXC_CONF="/obs.service.$$"
echo "lxc.utsname = obs.service.$$" > $LXC_CONF
if [ "$WITH_NET" != "1" ] ; then
  echo "lxc.network.type = empty" >> $LXC_CONF
  echo "lxc.network.flags = up" >> $LXC_CONF
fi
#echo "lxc.pts = 1" >> $LXC_CONF
echo "lxc.tty = 1" >> $LXC_CONF
#echo "lxc.mount = /etc/fstab" >> $LXC_CONF
echo "lxc.rootfs = $MOUNTDIR" >> $LXC_CONF
mount -t proc proc $MOUNTDIR/proc

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
  for i in _service:* ; do
    if [ ! -f "$MOUNTDIR/$INNERSRCDIR/$i" ]; then
      rm -f "$i"
    fi
  done
fi

# cleanup
umount "$MOUNTDIR/proc"
umount "$MOUNTDIR$INNERSRCDIR"
umount "$MOUNTDIR$INNEROUTDIR"
umount "$MOUNTDIR"
rm "$MOUNTDIR/$INNERSCRIPT"
rmdir "$MOUNTDIR/$TEMPDIR"
rmdir "$MOUNTDIR"

exit $RETURN

