#!/bin/bash

#set -x

#FSDIR="/opt/obs/SourceServiceSystem"
DOCKER_IMAGE=suse/sles12sp1-source-service:latest
SERVICES_DIR="/srv/obs/service/"

SCM_COMMAND=0
WITH_NET=0
COMMAND="$1"

shift
case "$COMMAND" in
  */download_url|*/download_src_package|*/update_source|*/download_files|*/generator_pom)
    WITH_NET="1"
    ;;
  */tar_scm|*/obs_scm)
    SCM_COMMAND=1
    WITH_NET="1"
  ;;
esac

while [ $# -gt 0 ]; do
  case $1 in 
    --scm)
      PARAM_SCM=$2
    ;;
    --scm=*)
      PARAM_SCM=$1
      PARAM_SCM=${PARAM_SCM#--scm=}
    ;;
    --url)
      PARAM_URL=$2
    ;;
    --url=*)
      PARAM_URL=$1
      PARAM_URL=${PARAM_URL#--url=}
    ;;
  esac
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

MOUNTDIR=`dirname $OUTDIR`
RETURN="0"
[ -d $MOUNTDIR ] || mkdir -p $MOUNTDIR
# set -x

# FIXME:
# Use an none world writable dir here
# and use mktemp
INNEROUTDIR="/tmp/$$/out"
OUTEROUTDIR="$MOUNTDIR/out"
INNERSRCDIR="/tmp/$$/src"
OUTERSRCDIR="$MOUNTDIR/src"
INNERSCRIPTDIR="/tmp/$$/scripts"
INNERSCRIPT="$INNERSCRIPTDIR/inner.sh"
INNERGITCACHE="/tmp/git-cache"

[ -d $OUTEROUTDIR ] || mkdir -p $OUTEROUTDIR
[ -d $OUTERSRCDIR ] || mkdir -p $OUTERSRCDIR
[ -d $MOUNTDIR$INNERSCRIPTDIR ] || mkdir -p $MOUNTDIR$INNERSCRIPTDIR

# Create inner.sh which is just a wrapper for 
# su nobody -s inner.sh.command
echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"
echo -n "su $RUNUSER -s ${INNERSCRIPT}.command" >> "$MOUNTDIR/$INNERSCRIPT"

# Create inner.sh.command
# dirname /srv/obs/service/11875/out/
echo "#!/bin/bash"               >  "$MOUNTDIR/${INNERSCRIPT}.command"
chmod 0755 "$MOUNTDIR/$INNERSCRIPT" "$MOUNTDIR/${INNERSCRIPT}.command"
echo "set -x" >> "$MOUNTDIR/${INNERSCRIPT}.command"
echo "echo Running ${COMMAND[@]} --outdir $INNEROUTDIR" >> "$MOUNTDIR/${INNERSCRIPT}.command"

DOCKER_OPTS_NET="--net=host"
if [ "$WITH_NET" != "1" ] ; then
  DOCKER_OPTS_NET="--net=none"
fi

DOCKER_VOLUMES="-v $OUTEROUTDIR:$INNEROUTDIR -v $OUTERSRCDIR:$INNERSRCDIR -v $MOUNTDIR$INNERSCRIPTDIR:$INNERSCRIPTDIR"
JAILED=""

if [ $SCM_COMMAND -eq 1 -a "$PARAM_SCM" == "git" ];then
  URL_HASH=`echo $PARAM_URL|sha256sum|cut -f1 -d\ `
  OUTERGITCACHE="$SERVICES_DIR/git-cache/$URL_HASH"
  DOCKER_VOLUMES="$DOCKER_VOLUMES -v $OUTERGITCACHE:$INNERGITCACHE"
  echo "export CACHEDIRECTORY='$INNERGITCACHE'" >> "$MOUNTDIR/${INNERSCRIPT}.command"
  JAILED="--jailed=1"
fi
echo "${COMMAND[@]} --outdir $INNEROUTDIR $JAILED" >> "$MOUNTDIR/${INNERSCRIPT}.command"

# useful for debugging purposes
#DEBUG_OPTIONS="-it"
#INNERSCRIPT=/bin/bash

# run jailed process
if docker run $DOCKER_OPTS_NET --rm --name src-service-$$ $DOCKER_VOLUMES $DEBUG_OPTIONS $DOCKER_IMAGE $INNERSCRIPT; then
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

rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNERSRCDIR"
rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNEROUTDIR"
rm -f "$MOUNTDIR/${INNERSCRIPT}.command" 2> /dev/null
rm -f "$MOUNTDIR/$INNERSCRIPT" 2> /dev/null
rmdir --ignore-fail-on-non-empty "$MOUNTDIR$INNERSCRIPTDIR" 2> /dev/null
rmdir --ignore-fail-on-non-empty "$MOUNTDIR" 2> /dev/null

exit $RETURN
