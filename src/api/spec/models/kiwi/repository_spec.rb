require 'rails_helper'
require 'rantly/rspec_extensions'

RSpec.describe Kiwi::Repository, type: :model do
  let(:kiwi_repository) { create(:kiwi_repository) }

  describe 'validations' do
    context 'for source_path' do
      it { is_expected.to validate_presence_of(:source_path) }

      ['dir', 'iso', 'smb', 'this'].each do |protocol|
        it "valid" do
          property_of {
            protocol + '://' + sized(range(1, 199)) { string(/./) }
          }.check(3) { |string|
            is_expected.to allow_value(string).for(:source_path)
          }
        end
      end

      ['ftp', 'http', 'https', 'plain'].each do |protocol|
        it "valid" do
          property_of {
            # TODO: improve regular expression to generate the URI
            protocol + '://' + sized(range(1, 199)) { string(/[\w]/) }
          }.check(3) { |string|
            is_expected.to allow_value(string).for(:source_path)
          }
        end
      end

      [nil, 3].each do |format|
        it { is_expected.not_to allow_value(format).for(:source_path) }
      end

      it "not valid when protocol is not valid" do
        property_of {
          string = sized(range(3, 199)) { string(/[\w]/) }
          index = range(0, (string.length - 4))
          string[index] = ':'
          string[index + 1] = string[index + 2] = '/'
          guard !%w(ftp http https plain dir iso smb this).include?(string[0..index - 1])
          string
        }.check(3) { |string|
          is_expected.not_to allow_value(string).for(:source_path)
        }
      end

      ['ftp', 'http', 'https', 'plain'].each do |protocol|
        it "not valid when has `{`" do
          property_of {
            string = sized(range(1, 199)) { string(/[\w]/) }
            index = range(0, (string.length - 2))
            uri_character = sized(1) { string(/[{]/) }
            string[index] = uri_character
            protocol + '://' + string
          }.check(3) { |string|
            is_expected.not_to allow_value(string).for(:source_path)
          }
        end
      end
    end

    it { is_expected.to validate_inclusion_of(:repo_type).in_array(%w(apt-deb rpm-dir rpm-md yast2)) }
    it { is_expected.to validate_numericality_of(:priority).is_greater_than_or_equal_to(0).is_less_than(100) }
    it { is_expected.to validate_numericality_of(:order).is_greater_than_or_equal_to(1) }
    it { is_expected.to allow_value(nil).for(:imageinclude) }
    it { is_expected.to allow_value(nil).for(:prefer_license) }
  end

  context 'do not update with outdated image' do
    let(:kiwi_repository) { create(:kiwi_repository_with_package) }
    before do
      allow_any_instance_of(Package).to receive(:kiwi_image_outdated?) { true }
    end

    it { expect{ kiwi_repository.update_attributes!(priority: 3) }.to raise_error(ActiveRecord::RecordNotSaved, 'Failed to save the record') }
  end

  describe '.to_xml' do
    subject { kiwi_repository.to_xml }

    it { expect(subject).to eq("<repository type=\"apt-deb\">\n  <source path=\"http://example.com/\"/>\n</repository>\n") }
  end
end
