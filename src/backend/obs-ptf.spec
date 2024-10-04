%global source_date_epoch_from_changelog 0

Name:           ptf-@patchinfo-incident@
Version:        @patchinfo-version@
Release:        0
Summary:	@patchinfo-summary@
License:        SUSE-Redistributable-Content
Group:          System/Packages
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Provides:       ptf() = @patchinfo-incident@-@patchinfo-version@
%if 0%{sle_version} >= 120000 && 0%{sle_version} <= 130000
Provides:       ptfdep-@filtered-rpm-name@ = @filtered-rpm-evr@
%else
Requires:       (@filtered-rpm-name@ = @filtered-rpm-evr@ if @filtered-rpm-name@)
%endif

%description
@patchinfo-description@

This ptf contains the following packages:
    @rpm-name@-@rpm-version@-@rpm-release@.@rpm-arch@

%build
cd %_sourcedir
odir="%_topdir/OTHER"
for i in *.rpm ; do
  case "$i" in
    *.src.rpm|*.nosrc.rpm)
      perl ./modifyrpmheader --add-description '\nThis package is part of %{name}-%{version}-%{release}\n' -- "$i" "$odir/$i"
      ;;
    *)
      perl ./modifyrpmheader --add-requires '%{name} = %{version}-%{release}' --add-provides 'ptf-package()' --add-description '\nThis package is part of %{name}-%{version}-%{release}\n' -- "$i" "$odir/$i"
      ;;
  esac
done
mkdir -p %{buildroot}/%{_defaultdocdir}/%{name}
cat >%{buildroot}/%{_defaultdocdir}/%{name}/README <<'EOF'
@patchinfo-description@

This ptf contains the following packages:
    @rpm-name@-@rpm-version@-@rpm-release@.@rpm-arch@

EOF

%files
%defattr(-,root,root)
%doc %{_defaultdocdir}/%{name}

%changelog

