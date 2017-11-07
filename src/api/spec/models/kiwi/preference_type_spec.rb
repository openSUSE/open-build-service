require 'rails_helper'

RSpec.describe Kiwi::PreferenceType, type: :model do
  let(:preference_type) { build(:kiwi_preference_type) }

  describe '#containerconfig_xml' do
    let(:expected_xml) do
      <<-XML.strip_heredoc
  <containerconfig name="my_container" containerconfig_tag="latest"/>
      XML
    end

    subject { preference_type.containerconfig_xml }

    it { expect(subject).to eq(expected_xml) }
  end
end
