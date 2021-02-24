Name:       hello_world
Version:    1
Release:    1
Summary:    Most simple RPM package
License:    CC0-1.0

%description
This is my first RPM package, which does nothing.

%prep
# we have no source, so nothing here

%build
cat > hello_world.sh <<EOF
#!/usr/bin/bash
echo Hello world
EOF

%install
mkdir -p %{buildroot}/usr/bin/
install -m 755 hello_world.sh %{buildroot}/usr/bin/hello_world.sh

%files
/usr/bin/hello_world.sh

%changelog
# let skip this for now
