#!/bin/bash

#set -x

function printlog {
  printf "%s %s %7s %s\n" `date +"%Y-%m-%d %H:%M:%S"` "[$$]" "$@" >> $LOGFILE
}

function create_dir {
  DIR=$1
  if [ ! -d $DIR ];then
    printlog "Creating directory '$DIR'"
    mkdir -p $DIR || exit 1
  else
    printlog "Directory '$DIR' already exists"
  fi
}

#FSDIR="/opt/obs/SourceServiceSystem"
DOCKER_IMAGE=`obs_admin --query-config docker_image`
DOCKER_CUSTOM_OPT=`obs_admin --query-config docker_custom_opt`
SERVICES_DIR=`obs_admin --query-config servicetempdir`
OBS_SERVICE_BUNDLE_GEMS_MIRROR_URL=`obs_admin --query-config gems_mirror`
SCM_COMMAND=0
WITH_NET=0
COMMAND="$1"
LOGDIR=/srv/obs/service/log/
LOGFILE=$LOGDIR/`basename $0`.log

if [[ ! $DOCKER_IMAGE ]];then
  DOCKER_IMAGE=suse/sles12sp2-source-service:latest
fi



printlog "$0 called:"
printlog "$@"

create_dir "$LOGDIR"

shift
case "$COMMAND" in
  */download_url|*/download_src_package|*/update_source|*/download_files|*/generator_pom|*/snapcraft|*/kiwi_import|*/appimage|*/bundle_gems)
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
     shift
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
create_dir "$MOUNTDIR"

# set -x
INNERBASEDIR=`mktemp -u /var/cache/obs/XXXXXXXXXXXX`
CONTAINER_ID=src-service-`basename $INNERBASEDIR`
INNEROUTDIR="$INNERBASEDIR/out"
OUTEROUTDIR="$MOUNTDIR/out"
INNERSRCDIR="$INNERBASEDIR/src"
OUTERSRCDIR="$MOUNTDIR/src"
INNERSCRIPTDIR="$INNERBASEDIR/scripts"
INNERSCRIPT="$INNERSCRIPTDIR/inner.sh"

OUTERHOMEDIR="$MOUNTDIR/home"
INNERHOMEDIR="$INNERBASEDIR/home"

create_dir "$OUTEROUTDIR"
create_dir "$OUTERSRCDIR"
create_dir "$MOUNTDIR$INNERSCRIPTDIR"
create_dir "$OUTERHOMEDIR"

# Create inner.sh which is just a wrapper for
# su nobody -s inner.sh.command

printlog "Creating INNERSCRIPT '$MOUNTDIR/$INNERSCRIPT'"
echo "#!/bin/bash"                                                                          > "$MOUNTDIR/$INNERSCRIPT"
echo "export OBS_SERVICE_APIURL=\"$OBS_SERVICE_APIURL\""                                   >> "$MOUNTDIR/$INNERSCRIPT"
echo "export OBS_SERVICE_BUNDLE_GEMS_MIRROR_URL=\"$OBS_SERVICE_BUNDLE_GEMS_MIRROR_URL\""   >> "$MOUNTDIR/$INNERSCRIPT"
echo "cd $INNERSRCDIR"                                                                     >> "$MOUNTDIR/$INNERSCRIPT"
echo -n "${INNERSCRIPT}.command"                                                           >> "$MOUNTDIR/$INNERSCRIPT"

# Create inner.sh.command
# dirname /srv/obs/service/11875/out/
printlog "Creating INNERSCRIPT.command '$MOUNTDIR/${INNERSCRIPT}.command'"
echo "#!/bin/bash"               			>  "$MOUNTDIR/${INNERSCRIPT}.command"
echo "set -x" 						>> "$MOUNTDIR/${INNERSCRIPT}.command"
echo "echo Running ${COMMAND[@]} --outdir $INNEROUTDIR" >> "$MOUNTDIR/${INNERSCRIPT}.command"

DOCKER_OPTS_NET="--net=bridge"
if [ "$WITH_NET" != "1" ] ; then
  printlog "Using docker without network"
  DOCKER_OPTS_NET="--net=none"
else
  printlog "Using docker with network"
fi

DOCKER_VOLUMES="-v $OUTEROUTDIR:$INNEROUTDIR -v $OUTERSRCDIR:$INNERSRCDIR -v $OUTERHOMEDIR:$INNERHOMEDIR -v $MOUNTDIR$INNERSCRIPTDIR:$INNERSCRIPTDIR:ro"
JAILED=""

if [ $SCM_COMMAND -eq 1 ];then
  URL_HASH=`echo $PARAM_URL|sha256sum|cut -f1 -d\ `
  OUTERSCMCACHE="$SERVICES_DIR/scm-cache/$URL_HASH"
  INNERSCMCACHE="$INNERBASEDIR/scm-cache"
  create_dir "$OUTERSCMCACHE"

  DOCKER_VOLUMES="$DOCKER_VOLUMES -v $OUTERSCMCACHE:$INNERSCMCACHE"
  echo "export CACHEDIRECTORY='$INNERSCMCACHE'" 	>> "$MOUNTDIR/${INNERSCRIPT}.command"
fi
FULL_COMMAND="${COMMAND[@]} --outdir $INNEROUTDIR"
printlog "FULL_COMMAND: '$FULL_COMMAND'"
echo "export HOME='$INNERHOMEDIR'" 			>> "$MOUNTDIR/${INNERSCRIPT}.command"
echo "$FULL_COMMAND" 					>> "$MOUNTDIR/${INNERSCRIPT}.command"


chmod 0755 "$MOUNTDIR/$INNERSCRIPT"
chmod 0755 "$MOUNTDIR/${INNERSCRIPT}.command"

# useful for debugging purposes
if [[ $DEBUG_DOCKER ]];then
	DEBUG_OPTIONS="-it"
	INNERSCRIPT=/bin/bash
fi

find $MOUNTDIR
# run jailed process
DOCKER_RUN_CMD="docker run -u 2:2 $DOCKER_OPTS_NET --rm --name $CONTAINER_ID $DOCKER_CUSTOM_OPT $DOCKER_VOLUMES $DEBUG_OPTIONS $DOCKER_IMAGE $INNERSCRIPT"
printlog "DOCKER_RUN_CMD: '$DOCKER_RUN_CMD'"
CMD_OUT=$(${DOCKER_RUN_CMD} 2>&1)
RET_ERR=$?
if [ $RET_ERR -eq 0 ]; then
  # move out the result
  if [ 0`find "$MOUNTDIR/$INNEROUTDIR" -type f 2>/dev/null| wc -l` -gt 0 ]; then
    for i in _service:* ; do
      if [ ! -f "$MOUNTDIR/$INNERSRCDIR/$i" ]; then
        rm -f "$i"
      fi
    done
  fi
elif [ $RET_ERR -eq 125 ] || [ $RET_ERR -eq 126 ] || [ $RET_ERR -eq 127 ]; then
  printlog "$CMD_OUT"
  echo "$CMD_OUT"
  RETURN="3"
else
  printlog "$CMD_OUT"
  echo "$CMD_OUT"
  RETURN="2"
fi

if [[ $DEBUG_DOCKER ]];then
  printlog "DEBUG_DOCKER is set. Skipping cleanup"
else
  printlog "Starting cleanup"
  [ -d "$MOUNTDIR/$INNERSRCDIR" ] && rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNERSRCDIR"
  [ -d "$MOUNTDIR/$INNEROUTDIR" ] && rmdir --ignore-fail-on-non-empty "$MOUNTDIR/$INNEROUTDIR"
  rm -f "$MOUNTDIR/${INNERSCRIPT}.command" 2> /dev/null
  rm -f "$MOUNTDIR/$INNERSCRIPT" 2> /dev/null
  rmdir --ignore-fail-on-non-empty "$MOUNTDIR$INNERSCRIPTDIR" 2> /dev/null
  rmdir --ignore-fail-on-non-empty "$MOUNTDIR" 2> /dev/null

  docker inspect $CONTAINER_ID > /dev/null 2>&1 && docker rm --force --volumes $CONTAINER_ID
fi

exit $RETURN
