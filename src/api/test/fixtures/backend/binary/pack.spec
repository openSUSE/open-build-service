Name:           pack
Version:        1.0
Release:        1
License:        Proprietary
Summary:        %{name}
#TAG

%description

%prep

%build

%install
mkdir -p $RPM_BUILD_ROOT
touch $RPM_BUILD_ROOT/empty.txt

%post

%postun

%files
/empty.txt

