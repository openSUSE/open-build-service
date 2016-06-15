Name: worker-deltagen
Version: 0
Release: 0
Summary: Build deltas for publishing
Group: Productivity/Networking/Web/Utilities
License: GPL
%description
Build deltas for publishing

%build
cd %_sourcedir
odir="%_topdir/OTHER"
mkdir -p "$odir"

# check if makedeltarpm supports the '-m' option
mopt=
case `makedeltarpm -m 512 /dev/null /dev/null /dev/null 2>&1` in
  *invalid\ option*) ;;
  *) mopt="-m 512" ;;
esac

for i in *.old ; do
  if ! test -e "$i"; then
    continue
  fi
  i="${i%.old}"
  rm -f "$odir/$i.drpm" "$odir/$i.out" "$odir/$i.seq" "$odir/$i.dseq"
  cat "$i.info"
  if makedeltarpm $mopt -s "$odir/$i.seq" "$i.old" "$i.new" "$odir/$i.drpm" >"$i.err" 2>&1 ; then
    rm -f "$odir/$i.err"
    newsize=$(stat -c %s "$i.new")
    drpmsize=$(stat -c %s "$odir/$i.drpm")
    let drpmsize=$drpmsize+$drpmsize
    if test $drpmsize -ge $newsize ; then
	rm -f "$odir/$i.drpm" "$odir/$i.seq"
        :> "$odir/$i.out"
	continue
    fi
    s=
    read s < "$odir/$i.seq"
    rm -f "$odir/$i.seq"
    if test -z "$s"; then
	echo "empty sequence" >> "$i.err"
	rm -f "$odir/$i.drpm"
	continue
    fi
    cp "$i.info" "$odir/$i.dseq"
    echo "Seq: $s" >> "$odir/$i.dseq"
  else
    cat "$i.err"
    rm -f "$odir/$i.drpm" "$odir/$i.seq"
  fi
done
