#!/bin/bash

#set -x

#FSDIR="/opt/obs/SourceServiceSystem"
DOCKER_IMAGE=suse/sles12sp1-source-service:latest
SERVICES_DIR="/srv/obs/service/"

SCM_COMMAND=0
WITH_NET=0
COMMAND="$1"
LOGDIR=/srv/obs/service/log/
LOGFILE=$LOGDIR/`basename $0`.log

function printlog {
  printf "%s %s %7s %s\n" `date +"%Y-%m-%d %H:%M:%S"` "[$$]" "$@" >> $LOGFILE
}

[ -d $LOGDIR ] || mkdir -p $LOGDIR

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
INNERBASEDIR=`mktemp -u /var/cache/obs/XXXXXXXXXXXX`
CONTAINER_ID=src-service-`basename $INNERBASEDIR`
INNEROUTDIR="$INNERBASEDIR/out"
OUTEROUTDIR="$MOUNTDIR/out"
INNERSRCDIR="$INNERBASEDIR/src"
OUTERSRCDIR="$MOUNTDIR/src"
INNERSCRIPTDIR="$INNERBASEDIR/scripts"
INNERSCRIPT="$INNERSCRIPTDIR/inner.sh"
INNERGITCACHE="$INNERBASEDIR/git-cache"

[ -d $OUTEROUTDIR ] || mkdir -p $OUTEROUTDIR
[ -d $OUTERSRCDIR ] || mkdir -p $OUTERSRCDIR
[ -d $MOUNTDIR$INNERSCRIPTDIR ] || mkdir -p $MOUNTDIR$INNERSCRIPTDIR

# Create inner.sh which is just a wrapper for
# su nobody -s inner.sh.command
echo "#!/bin/bash" > "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR" >> "$MOUNTDIR/$INNERSCRIPT"
echo -n "${INNERSCRIPT}.command" >> "$MOUNTDIR/$INNERSCRIPT"

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
FULL_COMMAND="${COMMAND[@]} --outdir $INNEROUTDIR $JAILED"
printlog "FULL_COMMAND: '$FULL_COMMAND'"
echo "$FULL_COMMAND" >> "$MOUNTDIR/${INNERSCRIPT}.command"

# useful for debugging purposes
if [[ $DEBUG_DOCKER ]];then
	DEBUG_OPTIONS="-it"
	INNERSCRIPT=/bin/bash
fi

# run jailed process
DOCKER_RUN_CMD="docker run -u `id -u $USER` $DOCKER_OPTS_NET --rm --name $CONTAINER_ID $DOCKER_VOLUMES $DEBUG_OPTIONS $DOCKER_IMAGE $INNERSCRIPT"
printlog "DOCKER_RUN_CMD: '$DOCKER_RUN_CMD'"
CMD_OUT=$(${DOCKER_RUN_CMD} 2>&1)
if [ $? -eq 0 ]; then
  # move out the result
  if [ 0`find "$MOUNTDIR/$INNEROUTDIR" -type f 2>/dev/null| wc -l` -gt 0 ]; then
    for i in _service:* ; do
      if [ ! -f "$MOUNTDIR/$INNERSRCDIR/$i" ]; then
        rm -f "$i"
      fi
    done
  fi
else
 printlog "$CMD_OUT"
 echo "$CMD_OUT"
exit 2
 RETURN="2"
fi


[ -d "$MOUNTDIR/$INNERSRCDIR" ] && rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNERSRCDIR"
[ -d "$MOUNTDIR/$INNEROUTDIR" ] && rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNEROUTDIR"
rm -f "$MOUNTDIR/${INNERSCRIPT}.command" 2> /dev/null
rm -f "$MOUNTDIR/$INNERSCRIPT" 2> /dev/null
rmdir --ignore-fail-on-non-empty "$MOUNTDIR$INNERSCRIPTDIR" 2> /dev/null
rmdir --ignore-fail-on-non-empty "$MOUNTDIR" 2> /dev/null

docker inspect $CONTAINER_ID > /dev/null 2>&1 && docker rm --force --volumes $CONTAINER_ID

exit $RETURN
