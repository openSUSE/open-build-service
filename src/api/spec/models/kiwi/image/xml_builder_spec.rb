require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Kiwi::Image::XmlBuilder do
  include_context 'a kiwi image xml'

  describe '#build' do
    let(:original_xml) do
      <<-XML.strip_heredoc
  <?xml version="1.0" encoding="UTF-8"?>
  <image name="Christians_openSUSE_13.2_JeOS" displayname="Christians_openSUSE_13.2_JeOS" schemaversion="5.2">
    <preferences>
      <type image="docker" boot="grub">
        <containerconfig name="my_container" tag="latest"/>
        <oemconfig>test</oemconfig>
      </type>
      <bootsplash-theme>gnome</bootsplash-theme>
      <bootloader-theme>gnome-dark</bootloader-theme>
    </preferences>
  </image>
      XML
    end
    let(:expected_xml) do
      <<-XML.strip_heredoc
  <?xml version="1.0" encoding="UTF-8"?>
  <image name="Christians_openSUSE_13.2_JeOS" displayname="Christians_openSUSE_13.2_JeOS" schemaversion="5.2">
    <preferences>
      <type image="docker" boot="grub">
        <containerconfig name="hello" tag="world"/>
        <oemconfig>test</oemconfig>
      </type>
      <bootsplash-theme>gnome</bootsplash-theme>
      <bootloader-theme>gnome-dark</bootloader-theme>
    </preferences>
  </image>
      XML
    end

    let(:kiwi_image) { Kiwi::Image.build_from_xml(original_xml, 'some_md5') }

    before do
      kiwi_image.save
      allow(kiwi_image).to receive(:kiwi_body).and_return(original_xml)
      kiwi_image.preference_type.containerconfig_name = 'hello'
      kiwi_image.preference_type.containerconfig_tag = 'world'
    end

    subject { Kiwi::Image::XmlBuilder.new(kiwi_image).build }

    it { is_expected.to eq(expected_xml) }
  end
end
