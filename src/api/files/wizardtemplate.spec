Name:           @name@
Version:        @version@
Release:        1
License:        GPL
Source:         @tarball@
Group:          @group@
Summary:        @summary@
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
@description@

%prep
%setup

%build
%configure
make

%install
make DESTDIR=%buildroot install

echo '%%defattr(-,root,root)' >filelist
find %buildroot -type f -printf '/%%P*\n' >>filelist

%clean
rm -rf %buildroot

%files -f filelist
%defattr(-,root,root)

%changelog
* @date@ @email@
- packaged @name@ version @version@ using the buildservice spec file wizard
