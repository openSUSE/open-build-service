Name:           <%= @name %>
# List of additional build dependencies
<% if @packtype == "python"
%>BuildRequires:  python-devel<%
  else
%>#BuildRequires:  gcc-c++ libxml2-devel<%
   end %>
Version:        <%= @version %>
Release:        1
License:        <%= @license %>
Source:         <%= @tarball %>
Group:          <%= @group %>
Summary:        <%= @summary %>
<% if @packtype == "perl"
%>Requires:       perl = %{perl_version}<%
   elsif @packtype == "python"
%>%py_requires<%
   end %>
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
<%= @description.gsub(/([^\n]{1,70})([ \t]+|\n|$)/, "\\1\n") %>

%prep
<%=
# FIXME: escape special characters in name and version
if @tarball =~ /^#{@name}-#{@version}\.tar\.(gz|bz2)$/
"%setup -q"
elsif @tarball =~ /^(.*)-#{@version}\.tar\.(gz|bz2)$/
"%setup -q -n #{$1}-%version"
elsif @tarball =~ /^(.*)\.tar\.(gz|bz2)$/
"%setup -q -n #{$1}"
else # give up
"%setup -q"
end
%>

%build
<% if @packtype == "generic" %>
# Assume that the package is built by plain 'make' if there's no ./configure.
# This test is there only because the wizard doesn't know much about the
# package, feel free to clean it up
if test -x ./configure; then
	%configure
fi
make
<% elsif @packtype == "perl" %>
perl Makefile.PL
make
<% elsif @packtype == "python" %>
python setup.py build
<% else raise RuntimeError.new("WizardError: unknown packtype #{@packtype}") %>
<% end %>
    

%install
<% if @packtype == "generic" %>
make DESTDIR=%buildroot install
<% elsif @packtype == "perl" %>
make DESTDIR=%buildroot install_vendor
%perl_process_packlist
<% elsif @packtype == "python" %>
python setup.py install --prefix=%_prefix --root=%buildroot --record-rpm=filelist
<% else raise RuntimeError.new("WizardError: unknown packtype #{@packtype}") %>
<% end %>

<% if @packtype != "python" %>
# Write a proper %%files section and remove these two commands and
# the '-f filelist' option to %%files
echo '%%defattr(-,root,root)' >filelist
find %buildroot -type f -printf '/%%P*\n' >>filelist
<% end %>

%clean
rm -rf %buildroot

%files -f filelist
%defattr(-,root,root)
<%
# '%files -f' seems to be standard practice in python packages, so only display
# the comment in non-python cases
if @packtype != "python" %>
# This is a place for a proper filelist:
# /usr/bin/<%= @name %>
# You can also use shell wildcards:
# /usr/share/<%= @name %>/*
# This installs documentation files from the top build directory
# into /usr/share/doc/...
# %doc README COPYING
# The advantage of using a real filelist instead of the '-f filelist' trick is
# that rpmbuild will detect if the install section forgets to install
# something that is listed here
<% end %>

%changelog
* <%= Date.today.strftime("%a %b %d %Y") %> <%= @email %>
- packaged <%= @name %> version <%= @version %> using the buildservice spec file wizard
