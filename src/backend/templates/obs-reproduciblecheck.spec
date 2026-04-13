%global source_date_epoch_from_changelog 0

Name:           reproduciblecheck
Version:        0
Release:        0
Summary:	reproduciblecheck
License:        SUSE-Redistributable-Content
Group:          System/Packages
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
reproduciblecheck

%build
cd %_sourcedir
odir="%_topdir/OTHER"
mkdir -p "$odir"

mkdir -p a b
for f in a_* ; do
  test -e "$f" && mv "$f" "a/${f#a_}"
done
rm -f a/_buildenv
for f in b_* ; do
  # create a copy, tools like delsign modify in-place
  test -e "$f" && cp -a "$f" "b/${f#b_}"
  test -e "$f" && mv "$f" "$odir/${f#b_}"
done

fail=
for f in a/* ; do
  test -e "$f" || continue
  f="${f#a/}"
  if ! test -e "b/$f" ; then
    echo "$f: missing in directory 'b'"
    fail=1
  else
    test "$f" = "${f%.rpm}" || rpm --delsign "a/$f"
    test "$f" = "${f%.rpm}" || rpm --delsign "b/$f"
    if ! cmp -s "a/$f" "b/$f" ; then
      echo "$f: not identical"
      fail=1
    else
      echo "$f: ok"
    fi
  fi
done
for f in b/* ; do
  test -e "$f" || continue
  test "$f" != "b/rpmlint.log" || continue
  test "$f" != "b/_buildenv" || continue
  f="${f#b/}"
  if ! test -e "a/$f" ; then
    echo "$f: missing in directory 'a'"
    fail=1
  fi
done

echo
if test -z "$fail" ; then
  echo "Result: OK"
  echo "----------"
else
  echo "Result: FAIL"
  echo "------------"
fi

%changelog

