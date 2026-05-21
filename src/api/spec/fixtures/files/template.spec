Name:       {{ package.name }}
Version:    1
Release:    1
Summary:    {{ package.title }}
License:    CC0-1.0

%description
{{ package.description }}

%prep
# we have no source, so nothing here

%build
cat > factory_package.sh <<EOF
#!/usr/bin/bash
echo Hello world, from factory_package.
EOF

%install
mkdir -p %{buildroot}/usr/bin/
install -m 755 factory_package.sh %{buildroot}/usr/bin/factory_package.sh

%files
/usr/bin/factory_package.sh

%changelog
# let skip this for now
