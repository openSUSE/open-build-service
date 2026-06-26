
Name:           obs-release
%define         product obs
%define         betaversion Beta2
Summary:        OBS
Version:        ___VERSION___
Release:        0
License:        BSD 3-Clause
Group:          System/Fhs

Provides:       obs-release

___PRODUCT_PROVIDES___

AutoReqProv:    on
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
___DESCRIPTION___


___FLAVOR_PACKAGES___

%prep

%build


%install
mkdir -p $RPM_BUILD_ROOT/etc
echo "OBS %{version} (%{_target_cpu})" > $RPM_BUILD_ROOT/etc/obs-release
echo VERSION = 11 >> $RPM_BUILD_ROOT/etc/obs-release
echo PATCHLEVEL = 2 >> $RPM_BUILD_ROOT/etc/obs-release

___CREATE_PRODUCT_FILES___

%clean
rm -rf %buildroot

%files
%defattr(644,root,root,755)
%dir /etc/products.d
/etc/products.d/*.prod
/etc/obs-release


%changelog
