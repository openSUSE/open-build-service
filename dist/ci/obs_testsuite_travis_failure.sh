#!/bin/bash

if [ -z "$ARTIFACTS_KEY" ] || [ -z "$ARTIFACTS_SECRET" ]; then
  echo 'No AWS secrets set...'
  exit 0 
fi

pushd src/api

function upload_to_s3 {
dateValue=`date -R`
stringToSign="PUT\n\ntext/plain\n${dateValue}\n/obs-travis-articafts/$TRAVIS_BUILD_NUMBER/$TRAVIS_JOB_NUMBER/$1"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${ARTIFACTS_SECRET} -binary | base64`
curl -X PUT -T $1 \
  -H "Host: obs-travis-articafts.s3.amazonaws.com" \
  -H "Date: ${dateValue}" \
  -H "Content-Type: text/plain" \
  -H "Authorization: AWS ${ARTIFACTS_KEY}:${signature}" \
  https://obs-travis-articafts.s3.amazonaws.com/$TRAVIS_BUILD_NUMBER/$TRAVIS_JOB_NUMBER/$1
}

if [ -f log/test.log ]; then
  upload_to_s3 log/test.log
  echo "Posted: https://obs-travis-articafts.s3.amazonaws.com/$TRAVIS_BUILD_NUMBER/$TRAVIS_JOB_NUMBER/log/test.log"
fi

for file in tmp/capybara/*; do
  upload_to_s3 $file
  echo "Posted: https://obs-travis-articafts.s3.amazonaws.com/$TRAVIS_BUILD_NUMBER/$TRAVIS_JOB_NUMBER/tmp/capybara/$file"
done
