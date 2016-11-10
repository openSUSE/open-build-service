#!/bin/bash

#set -x

FSDIR="/opt/obs/SourceServiceSystem"
MOUNTDIR="/opt/obs/SourceServiceSystem.mounts/"
TEMPDIR="/lxc.tmp.$$"
RETURN="0"

# set -x

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
  */download_url|*/tar_scm|*/obs_scm|*/download_src_package|*/update_source|*/download_files|*/generator_pom)
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
echo "#!/bin/bash"               >  "$MOUNTDIR/${INNERSCRIPT}.command"
#echo "set -x" >> "$MOUNTDIR/${INNERSCRIPT}.command"
#echo "ls -ld /dev /dev/null" >> "$MOUNTDIR/${INNERSCRIPT}.command"
echo "echo Running ${COMMAND[@]} --outdir $INNEROUTDIR" >> "$MOUNTDIR/${INNERSCRIPT}.command"
echo "${COMMAND[@]} --outdir $INNEROUTDIR" >> "$MOUNTDIR/${INNERSCRIPT}.command"
chmod 0755 "$MOUNTDIR/$INNERSCRIPT" "$MOUNTDIR/${INNERSCRIPT}.command"

# construct jail
LXC_CONF="/obs.service.$$"
echo "lxc.utsname = obs.service.$$" > $LXC_CONF
mount -t proc proc $MOUNTDIR/proc
if [ "$WITH_NET" != "1" ] ; then
  echo "lxc.network.type = empty" >> $LXC_CONF
  echo "lxc.network.flags = up" >> $LXC_CONF
fi
#echo "lxc.pts = 1" >> $LXC_CONF
echo "lxc.tty = 1" >> $LXC_CONF
#echo "lxc.mount = /etc/fstab" >> $LXC_CONF
echo "lxc.rootfs = $MOUNTDIR" >> $LXC_CONF
echo "lxc.autodev = 1" >> $LXC_CONF
echo "lxc.cgroup.devices.allow = c 1:3 rw" >> $LXC_CONF

lxc-info -n obs.service.jail.$$ >& /dev/null && lxc-destroy -n obs.service.jail.$$ >& /dev/null
RETURN="0"

# add -t none for lxc 1.1
lxc-create -n obs.service.jail.$$ -f $LXC_CONF >& /dev/null || RETURN="2"

# run jailed process
if lxc-start -n obs.service.jail.$$ "$INNERSCRIPT"; then
  # move out the result
  if [ 0`find "$MOUNTDIR/$INNEROUTDIR" -type f | wc -l` -gt 0 ]; then
    for i in _service:* ; do
      if [ ! -f "$MOUNTDIR/$INNERSRCDIR/$i" ]; then
        rm -f "$i"
      fi
    done
  fi
else
 RETURN="2"
fi

#ls $FSDIR

# cleanup
umount "$MOUNTDIR/proc"
umount "$MOUNTDIR$INNERSRCDIR"
umount "$MOUNTDIR$INNEROUTDIR"
rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNERSRCDIR"
rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNEROUTDIR"
rm -f "$MOUNTDIR/$INNERSCRIPT.command" 2> /dev/null
rm -f "$MOUNTDIR/$INNERSCRIPT" 2> /dev/null
rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$TEMPDIR" 2> /dev/null
umount "$MOUNTDIR" 
rmdir --ignore-fail-on-non-empty "$MOUNTDIR" 2> /dev/null
#ls $FSDIR

# destroy jail
# lxc-destroy -n obs.service.jail.$$
# lxc-destory removes the entire system now
rm -rf /var/lib/lxc/obs.service.jail.$$

exit $RETURN

