# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Kiwi::Description, type: :model do
  let(:kiwi_description) { create(:kiwi_description) }

  describe '#to_xml' do
    context 'with full description content' do
      let(:expected_xml) do
        <<-XML.strip_heredoc
          <description type="system">
            <author>example_author</author>
            <contact>example_contact</contact>
            <specification>example_specification</specification>
          </description>
        XML
      end

      subject { kiwi_description.to_xml }

      it { expect(subject).to eq(expected_xml) }
    end

    context 'with empty description content' do
      let(:expected_xml) do
        <<-XML.strip_heredoc
          <description type="system">
            <author/>
            <contact/>
            <specification/>
          </description>
        XML
      end

      subject { create(:kiwi_description, author: nil, contact: '', specification: nil).to_xml }

      it { expect(subject).to eq(expected_xml) }
    end
  end
end
