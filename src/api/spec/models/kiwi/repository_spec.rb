require 'rantly/rspec_extensions'

RSpec.describe Kiwi::Repository do
  let(:kiwi_repository) { create(:kiwi_repository) }
  let(:non_obs_kiwi_repository) { create(:kiwi_repository, source_path: 'http://example.com/my_repo') }
  let(:obs_kiwi_repository) { create(:kiwi_repository, source_path: 'obs://home:project/my_obs_repo') }
  let(:kiwi_repository_without_sourcepath) { build(:kiwi_repository, source_path: nil) }

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
    subject { create(:kiwi_repository) }

    context 'for source_path' do
      it { is_expected.to validate_presence_of(:source_path).with_message(/can't be nil/) }

      it 'obsrepositories should be valid' do
        expect(subject).to allow_value('obsrepositories:/').for(:source_path)
      end

      it 'validates "dir", "iso", "smb", and "this" protocols' do
        %w[dir iso smb this].each do |protocol|
          property_of do
            "#{protocol}://#{sized(range(1, 199)) { string(/./) }}"
          end.check(3) do |string|
            expect(subject).to allow_value(string).for(:source_path)
          end
        end
      end

      it 'validates "ftp", "http", "https" and "plain" protocols' do
        %w[ftp http https plain].each do |protocol|
          property_of do
            # TODO: improve regular expression to generate the URI
            "#{protocol}://#{sized(range(1, 199)) { string(/\w/) }}"
          end.check(3) do |string|
            expect(subject).to allow_value(string).for(:source_path)
          end
        end
      end

      it 'obs:// is valid' do
        property_of do
          project = []
          range(1, 3).times do
            project << (string(/[a-zA-Z1-9]/) + sized(range(0, 20)) { string(/[-+\w.]/) })
          end
          repository = []
          range(1, 3).times do
            repository << (string(/[a-zA-Z1-9]/) + sized(range(0, 20)) { string(/[-+\w.]/) })
          end
          path = "obs://#{project.join(':')}/#{repository.join(':')}"
          path
        end.check(3) do |string|
          expect(subject).to allow_value(string).for(:source_path)
        end
      end

      [nil, 3].each do |format|
        it { is_expected.not_to allow_value(format).for(:source_path) }
      end

      it 'not valid when protocol is not valid' do
        property_of do
          string = sized(range(3, 199)) { string(/\w/) }
          index = range(0, string.length - 3)
          string[index] = ':'
          string[index + 1] = string[index + 2] = '/'
          guard(%w[ftp http https plain dir iso smb this obs].exclude?(string[0..index - 1]))
          string
        end.check(3) do |string|
          expect(subject).not_to allow_value(string).for(:source_path)
        end
      end

      %w[ftp http https plain obs].each do |protocol|
        it 'not valid when has `{`' do
          property_of do
            string = sized(range(1, 199)) { string(/\w/) }
            index = range(0, string.length - 1)
            uri_character = sized(1) { string(/[{]/) }
            string[index] = uri_character
            "#{protocol}://#{string}"
          end.check(3) do |string|
            expect(subject).not_to allow_value(string).for(:source_path)
          end
        end
      end

      context 'when source_path starts with obs://' do
        it { expect(obs_kiwi_repository).to allow_value('rpm-md').for(:repo_type) }

        Kiwi::Repository::REPO_TYPES.reject { |repo| repo == 'rpm-md' }.each do |type|
          it { expect(obs_kiwi_repository).not_to allow_value(type).for(:repo_type) }
        end
      end
    end

    # We specific the context of the inclusion validation because of a bug in shoulda_matcher.
    # Remove `.on(:save)` when it's solved.
    it do
      expect(subject).to validate_inclusion_of(:repo_type).in_array(Kiwi::Repository::REPO_TYPES).on(:save)
                                                          .with_message(/is not included in the list/)
    end

    it do
      expect(subject).to validate_numericality_of(:priority).is_greater_than_or_equal_to(0).is_less_than(100)
                                                            .with_message(/must be between 0 and 99/)
    end

    it { is_expected.to validate_numericality_of(:order).is_greater_than_or_equal_to(1) }
    it { is_expected.to allow_value(nil).for(:imageinclude) }
    it { is_expected.to allow_value(nil).for(:prefer_license) }
  end

  describe '#to_xml' do
    context 'without username/password' do
      subject { kiwi_repository.to_xml }

      it { expect(subject).to eq("<repository type=\"rpm-md\">\n  <source path=\"http://example.com/\"/>\n</repository>\n") }
    end

    context 'with username/password' do
      subject { create(:kiwi_repository, username: 'my_user', password: 'my_password').to_xml }

      it do
        expect(subject).to eq("<repository type=\"rpm-md\" username=\"my_user\" password=\"my_password\">\n  " \
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with prefer_license' do
      subject { create(:kiwi_repository, prefer_license: true).to_xml }

      it do
        expect(subject).to eq("<repository type=\"rpm-md\" prefer-license=\"true\">\n  " \
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with imageinclude' do
      subject { create(:kiwi_repository, imageinclude: true).to_xml }

      it do
        expect(subject).to eq("<repository type=\"rpm-md\" imageinclude=\"true\">\n  " \
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end

    context 'with alias' do
      subject { create(:kiwi_repository, alias: 'example').to_xml }

      it do
        expect(subject).to eq("<repository type=\"rpm-md\" alias=\"example\">\n  " \
                              "<source path=\"http://example.com/\"/>\n</repository>\n")
      end
    end
  end

  describe '#obs_source_path?' do
    context 'with non OBS repository' do
      subject { non_obs_kiwi_repository.obs_source_path? }

      it { is_expected.to be_falsey }
    end

    context 'with a repository without source_path' do
      subject { kiwi_repository_without_sourcepath.obs_source_path? }

      it { is_expected.to be_falsey }
    end

    context 'with an OBS repository' do
      subject { obs_kiwi_repository.obs_source_path? }

      it { is_expected.to be_truthy }
    end
  end

  describe '#project_for_type_obs' do
    context 'with non OBS repository' do
      subject { non_obs_kiwi_repository.project_for_type_obs }

      it { is_expected.to be_nil }
    end

    context 'with a repository without source_path' do
      subject { kiwi_repository_without_sourcepath.project_for_type_obs }

      it { is_expected.to eq('') }
    end

    context 'with an OBS repository' do
      subject { obs_kiwi_repository.project_for_type_obs }

      it { is_expected.to eq('home:project') }
    end
  end

  describe '#repository_for_type_obs' do
    context 'with non OBS repository' do
      subject { non_obs_kiwi_repository.repository_for_type_obs }

      it { is_expected.to be_nil }
    end

    context 'with a repository without source_path' do
      subject { kiwi_repository_without_sourcepath.repository_for_type_obs }

      it { is_expected.to eq('') }
    end

    context 'with an OBS repository' do
      subject { obs_kiwi_repository.repository_for_type_obs }

      it { is_expected.to eq('my_obs_repo') }
    end
  end
end
