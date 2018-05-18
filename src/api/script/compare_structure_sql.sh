#!/bin/sh

git_file="$1"
migrate_file="$2"

for file in "$git_file" "$migrate_file"; do
  cp "$file" "${file}.normalized" || exit 1
  # ignore default change in mysql
  sed -i -e 's, USING BTREE,,' "${file}.normalized" || exit 1
  # ignore old migrations including first current one
  sed -i -e '/^INSERT INTO `schema_migrations`.*/,/^(.20140210114542.)/d' "${file}.normalized" || exit 1
  # dropped migration
  sed -i -e '/^(.20141302101042.).$/d' "${file}.normalized" || exit 1
  # ignore very old migrations
  sed -i -e '/^(.21.),$/,/^(.9.);/d' "${file}.normalized" || exit 1
  # we have a different last migration, therefore ; => ,
  sed -i -e 's/\(^(.20.............)\);$/\1,/' "${file}.normalized" || exit 1
  # From MariaDB 10.2.2, numbers are no longer quoted in the DEFAULT clause in SHOW CREATE statement.
  # https://mariadb.com/kb/en/library/show-create-table/
  # TODO: drop this line when we drop support for Mariadb < 10.2.2 (SLE12 & Leap 42.3)
  sed -i -r "s/DEFAULT '([[:digit:]]+)'/DEFAULT \1/g" "${file}.normalized" || exit 1
  # MariaDB 10.2.1 permits TEXT and BLOB data types to be assigned a DEFAULT value.
  # As a result, from MariaDB 10.2.1, SHOW CREATE TABLE will append a DEFAULT NULL
  # to nullable TEXT or BLOB fields if no specific default is provided.
  # https://mariadb.com/kb/en/library/show-create-table/
  # TODO: drop this line when we drop support for Mariadb < 10.2.2 (SLE12 & Leap 42.3)
  sed -r "s/(\`[a-zA-Z0-9]*\` (medium)*text [a-zA-Z0-9 ]*) DEFAULT NULL,/\1,/g"
done

if ! diff "${git_file}.normalized" "${migrate_file}.normalized"; then
  echo "ERROR: Migration is producing a different structure.sql"
  diff -u "${git_file}.normalized" "${migrate_file}.normalized"
  exit 1
fi

exit 0
