#!/bin/sh
if [ ${#*} = 1 ] ; then
    if [ -d "$1" ] ; then
        find $1 \
        \( -name \*.o -o -name Makefile -o -name config.log -o -name config.status -o -name Makefile.html -o -name gem_make.out -o -name mkmf.log -o -name \*.bak -o -name .deps -o -name .libs -o -name CVS \) \
            -print0 | xargs -r0 rm -rv || :
	# remove more strict in the docu
        find $1/doc \( -name Makefile.ri -o -name ext -o -name page\*.ri \) -print0 | xargs -r0 rm -rv || :
    else
        echo "'$1' does not exists or is not a directory! Exiting." >&2
        exit 1
    fi
else
    echo "Please pass exact one argument to this script! Exiting." >&2
    exit 1
fi
