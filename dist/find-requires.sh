#!/bin/bash

sourcearchive=$1
shift
prefix=$1
shift

tdir=`mktemp -d`

# extract files
tar xJf $sourcearchive -C $tdir >&/dev/null

pushd $tdir/open-build-service*/src/api >& /dev/null
ruby -rbundler -e 'exit' || echo "_ERROR_BUNDLER_NOT_INSTALLED_"
ruby -rbundler -e 'Bundler.definition.resolve.to_a.each { |s| puts "rubygem('$prefix':#{s.name}) = #{s.version}" }' | while read i; do echo -n $i", "; done
popd >& /dev/null

#cleanup
rm -rf $tdir

