#!/bin/sh

git_file="$1"
migrate_file="$2"

for file in "$git_file" "$migrate_file"; do
  cp "$file" "${file}.normalized" || exit 1
  # ignore default changes in mysql. Note: we need to support both setups here,
  # since old and new installations differ. We assume it makes no differences to us though
  sed -i -e 's, USING BTREE,,' "${file}.normalized" || exit 1
  # ignore old migrations including first current one
  sed -i -e '/^INSERT INTO `schema_migrations`.*/,/^(.20140210114542.)/d' "${file}.normalized" || exit 1
  # dropped migration
  sed -i -e '/^(.20141302101042.).$/d' "${file}.normalized" || exit 1
  # ignore very old migrations
  sed -i -e '/^(.21.),$/,/^(.9.);/d' "${file}.normalized" || exit 1
  # we have a different last migration, therefore ; => ,
  sed -i -e 's/\(^(.20.............)\);$/\1,/' "${file}.normalized" || exit 1
done

if ! diff "${git_file}.normalized" "${migrate_file}.normalized"; then
  echo "ERROR: Migration is producing a different structure.sql"
  diff -u "${git_file}.normalized" "${migrate_file}.normalized"
  exit 1
fi

exit 0
