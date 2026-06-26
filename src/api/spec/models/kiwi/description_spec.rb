RSpec.describe Kiwi::Description do
  let(:kiwi_description) { create(:kiwi_description) }

  describe '#to_xml' do
    context 'with full description content' do
      subject { kiwi_description.to_xml }

      let(:expected_xml) do
        <<~XML
          <description type="system">
            <author>example_author</author>
            <contact>example_contact</contact>
            <specification>example_specification</specification>
          </description>
        XML
      end

      it { expect(subject).to eq(expected_xml) }
    end

    context 'with empty description content' do
      subject { create(:kiwi_description, author: nil, contact: '', specification: nil).to_xml }

      let(:expected_xml) do
        <<~XML
          <description type="system">
            <author/>
            <contact/>
            <specification/>
          </description>
        XML
      end

      it { expect(subject).to eq(expected_xml) }
    end
  end
end
