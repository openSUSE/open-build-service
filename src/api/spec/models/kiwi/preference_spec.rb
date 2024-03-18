RSpec.describe Kiwi::Preference do
  let(:preference) { build(:kiwi_preference) }

  describe 'validations' do
    it { is_expected.to allow_value('12.3.456').for(:version) }
    it { is_expected.not_to allow_value('1.2.a').for(:version) }
    it { is_expected.not_to allow_value('1/2').for(:version) }
  end

  describe '#containerconfig_xml' do
    subject { preference.containerconfig_xml }

    let(:expected_xml) do
      <<~XML
        <containerconfig name="my_container" type_containerconfig_tag="latest"/>
      XML
    end

    it { expect(subject).to eq(expected_xml) }
  end
end
