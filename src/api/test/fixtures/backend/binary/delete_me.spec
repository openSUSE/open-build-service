# Minimal rpm package for testing the build controller
#
# build the binaries with "rpmbuild -ba package.spec"

Name:           delete_me
License:        GPLv2+
Group:          Development/Tools/Building
AutoReqProv:    on
Summary:        Test Package
Version:        1.0
Release:        1
Requires:       bash
Conflicts:      something
Provides:       myself

%description

%prep

%build

%install
mkdir -p $RPM_BUILD_ROOT
echo "CONTENT" > $RPM_BUILD_ROOT/my_packaged_file

%files
%defattr(-,root,root)
/my_packaged_file

%changelog
