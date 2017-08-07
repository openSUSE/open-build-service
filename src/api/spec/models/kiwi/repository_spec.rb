require 'rails_helper'
require 'rantly/rspec_extensions'

RSpec.describe Kiwi::Repository, type: :model do
  let(:kiwi_repository) { create(:kiwi_repository) }

  describe '#name' do
    context 'with an alias' do
      subject { create(:kiwi_repository, alias: 'my_alias_repo') }

      it { expect(subject.name).to eq('my_alias_repo') }
    end

    context 'without alias' do
      subject { create(:kiwi_repository, alias: nil, source_path: 'http://example.org/my_repo') }

      it { expect(subject.name).to eq('http:__example.org_my_repo') }
    end
  end

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

    it { is_expected.to validate_inclusion_of(:repo_type).in_array(Kiwi::Repository::REPO_TYPES) }
    it { is_expected.to validate_numericality_of(:priority).is_greater_than_or_equal_to(0).is_less_than(100) }
    it { is_expected.to validate_numericality_of(:order).is_greater_than_or_equal_to(1) }
    it { is_expected.to allow_value(nil).for(:imageinclude) }
    it { is_expected.to allow_value(nil).for(:prefer_license) }
  end

  describe '#to_xml' do
    context 'without username/password' do
      subject { kiwi_repository.to_xml }

      it { expect(subject).to eq("<repository type=\"apt-deb\">\n  <source path=\"http://example.com/\"/>\n</repository>\n") }
    end

    context 'with username/password' do
      subject { create(:kiwi_repository, username: 'my_user', password: 'my_password').to_xml }

      it do
        expect(subject).to eq("<repository type=\"apt-deb\" username=\"my_user\" password=\"my_password\">\n  " +
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with prefer_license' do
      subject { create(:kiwi_repository, prefer_license: true).to_xml }

      it do
        expect(subject).to eq("<repository type=\"apt-deb\" prefer-license=\"true\">\n  " +
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with imageinclude' do
      subject { create(:kiwi_repository, imageinclude: true).to_xml }

      it do
        expect(subject).to eq("<repository type=\"apt-deb\" imageinclude=\"true\">\n  " +
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with alias' do
      subject { create(:kiwi_repository, alias: 'example').to_xml }

      it do
        expect(subject).to eq("<repository type=\"apt-deb\" alias=\"example\">\n  " +
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end
  end
end
