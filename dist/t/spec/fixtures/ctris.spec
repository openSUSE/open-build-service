Name:         	ctris
Summary:      	Console based tetris clone
URL:          	http://www.hackl.dhs.org/ctris/ 
Group:        	Amusements/Games/Action/Arcade
License:      	GPL
Version:      	0.42
Release:      	1
Source0:       	%{name}-%{version}.tar.bz2
BuildRequires: 	ncurses-devel
BuildRoot:    	%{_tmppath}/%{name}-%{version}-build

%description
ctris is a colorized, small and flexible Tetris(TM)-clone for the console. Go play!

%prep
%setup -q

%build
make CFLAGS="$RPM_OPT_FLAGS"

%install
make install DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT;

%files
%defattr (-,root,root)
%doc AUTHORS COPYING README TODO
%doc %{_mandir}/man6/ctris.6.gz
/usr/games
/usr/games/ctris
