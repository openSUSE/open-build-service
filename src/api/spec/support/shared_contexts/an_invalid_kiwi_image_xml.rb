RSpec.shared_context 'an invalid kiwi image xml' do
  let(:invalid_kiwi_xml) do
    <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<image name="Christians_openSUSE_13.2_JeOS" displayname="Christians_openSUSE_13.2_JeOS" schemaversion="5.2">
  <description type="system">
    <author>Christian Bruckmayer</author>
    <contact>noemail@example.com</contact>
    <specification>Tiny, minimalistic appliances</specification>
  </description>
  <packages type="image" patternType="onlyRequired">
    <package name="e2fsprogs"/>
    <package name="aaa_base"/>
    <package name="branding-openSUSE"/>
    <package name="patterns-openSUSE-base"/>
    <package name="grub2"/>
    <package name="hwinfo"/>
    <package name="iputils"/>
    <package name="kernel-default"/>
    <package name="netcfg"/>
    <package name="openSUSE-build-key"/>
    <package name="openssh"/>
    <package name="plymouth"/>
    <package name="polkit-default-privs"/>
    <package name="rpcbind"/>
    <package name="syslog-ng"/>
    <package name="vim"/>
    <package name="zypper"/>
    <package name="timezone"/>
    <package name="openSUSE-release-dvd"/>
    <package name="gfxboot-devel" bootinclude="true"/>
  </packages>
  <repository type="wrong" priority="10" alias="debian" imageinclude="true" password="123456" prefer-license="true" status="replaceable" username="Tom">
    <source path="http://download.opensuse.org/update/13.2/"/>
  </repository>
  <repository type="rpm-dir" priority="wrong" imageinclude="false" prefer-license="false">
    <source path="http://download.opensuse.org/distribution/13.2/repo/oss/"/>
  </repository>
  <repository type="rpm-md" priority="20">
    <source path="wrong://download.opensuse.org/distribution/13.1/repo/oss/"/>
  </repository>
  <repository type="rpm-md">
    <source path="http://download.opensuse.org/distribution/12.1/repo/oss/"/>
  </repository>
</image>
    XML
  end
end
