Name:           ptf-@patchinfo-incident@
Version:        @patchinfo-version@
Release:        0
Summary:	@patchinfo-summary@
License:        SUSE-Redistributable-Content
Group:          System/Packages
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Provides:       ptf() = @patchinfo-incident@-@patchinfo-version@
Requires:       (@filtered-rpm-name@ = @filtered-rpm-evr@ if @filtered-rpm-name@)

%description
@patchinfo-description@

This ptf contains the following packages:
    @rpm-name@-@rpm-version@-@rpm-release@.@rpm-arch@

%build
cd %_sourcedir
odir="%_topdir/OTHER"
cp *.rpm "$odir"
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

