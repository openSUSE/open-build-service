# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Kiwi::Preference, type: :model do
  let(:preference) { build(:kiwi_preference) }

  describe 'validations' do
    it { is_expected.to allow_value('12.3.456').for(:version) }
    it { is_expected.not_to allow_value('1.2.a').for(:version) }
    it { is_expected.not_to allow_value('1.2').for(:version) }
  end

  describe '#containerconfig_xml' do
    let(:expected_xml) do
      <<-XML.strip_heredoc
  <containerconfig name="my_container" type_containerconfig_tag="latest"/>
      XML
    end

    subject { preference.containerconfig_xml }

    it { expect(subject).to eq(expected_xml) }
  end
end
