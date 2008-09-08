Name:           ___PACKAGE_NAME___
%define product ___PRODUCT_NAME___
# what's the default flavor ?
%define flavor  none
License:        BSD 3-Clause
Group:          System/Fhs
Version:        ___VERSION___
Release:        ___RELEASE___
Provides:       aaa_version distribution-release
Provides:       suse-release-oss = %{version}-%{release}
Provides:       suse-release = %{version}-%{release}
# Code11 product
Provides:       product()
Provides:       product(%{product}) = %{version}-%{release}
Obsoletes:      aaa_version
Obsoletes:      suse-release-oss <= 10.0 suse-release <= 10.1.42
Conflicts:      sles-release <= 10 sled-release <= 10 core-release <= 10
BuildRequires:  skelcd-control-___PRODUCT_NAME___
AutoReqProv:    on
Summary:        ___SUMMARY___
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
PreReq:         coreutils
%define betaversion ___BETA_VERSION___

%description
___DESCRIPTION___

___FLAVOR_PACKAGES___

%prep

%build

%install
mkdir -p $RPM_BUILD_ROOT/etc
echo -e 'Welcome to %{product} %{betaversion} - Kernel \\r (\\l).\n\n' > $RPM_BUILD_ROOT/etc/issue
echo "Welcome to %{product} %{betaversion} - Kernel %%r (%%t)." > $RPM_BUILD_ROOT/etc/issue.net
echo %{product} "%{betaversion}" > $RPM_BUILD_ROOT/etc/SuSE-release
echo VERSION = %{version} >> $RPM_BUILD_ROOT/etc/SuSE-release
echo "Have a lot of fun..." > $RPM_BUILD_ROOT/etc/motd
# Bug 404141 - /etc/YaST/control.xml should be owned by some package
mkdir -p $RPM_BUILD_ROOT/etc/YaST2/
echo $RPM_BUILD_ROOT
cp -av /CD1/control.xml $RPM_BUILD_ROOT/etc/YaST2/

___CREATE_PRODUCT_FILES___

%post
rm -rf /etc/zypp/products.d

%files
%defattr(644,root,root,755)
%config /etc/SuSE-release
# Bug 404141 - /etc/YaST/control.xml should be owned by some package
%dir /etc/YaST2/
%config /etc/YaST2/control.xml
%config /etc/motd
%config(noreplace) /etc/issue
%config(noreplace) /etc/issue.net

