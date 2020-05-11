# Minimal rpm package for testing the build controller
#
# build the binaries with "rpmbuild -ba package.spec"

# WARNING: you need to build this with rpmbuild from openSUSE 13.1 or older (eg. SLES 11)

%global disturl obs://testsuite/BaseDistro/repo/ce167c27b536e6ca39f8d951fa02a4ff-package

Name:           package
License:        GPLv2+
Group:          Development/Tools/Building
AutoReqProv:    on
Summary:        Test Package
Version:        1.0
Release:        1
Requires:       bash
Conflicts:      something
Obsoletes:      old_crap
Provides:       myself
Recommends:     would_be_nice
Suggests:       pure_optional
Enhances:       other_package
Supplements:    other_package_likes_it

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
