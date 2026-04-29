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
resultfile="$odir/reproduciblecheck.log"
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
rm -f "$resultfile"

fail=
for f in a/* ; do
  test -e "$f" || continue
  f="${f#a/}"
  if ! test -e "b/$f" ; then
    echo "$f: missing in directory 'b'"
    echo "MISS $f" >> "$resultfile"
    fail=1
  else
    test "$f" = "${f%.rpm}" || rpm --delsign "a/$f"
    test "$f" = "${f%.rpm}" || rpm --delsign "b/$f"
    if ! cmp -s "a/$f" "b/$f" ; then
      echo "$f: not identical"
      echo "FAIL $f" >> "$resultfile"
      fail=1
    else
      echo "$f: ok"
      echo "PASS $f" >> "$resultfile"
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
    echo "MISS $f" >> "$resultfile"
    fail=1
  fi
done

echo
echo >> "$resultfile"
if test -z "$fail" ; then
  echo "Result: PASS" >> "$resultfile"
  echo "result: PASS"
  echo "------------"
else
  echo "Result: FAIL" >> "$resultfile"
  echo "result: FAIL"
  echo "------------"
fi

%changelog

