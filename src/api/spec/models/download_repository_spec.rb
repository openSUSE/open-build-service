RSpec.describe DownloadRepository do
  describe 'validations' do
    subject(:download_repository) { create(:download_repository) }

    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:arch) }
    it { is_expected.to validate_presence_of(:repotype) }
    it { is_expected.to belong_to(:repository) }
    it { is_expected.to validate_uniqueness_of(:arch).scoped_to(:repository_id).case_insensitive }

    it do
      expect(subject).to validate_inclusion_of(:repotype).in_array(%w[rpmmd susetags deb arch mdk registry apk])
                                                         .with_message(/is not a valid repotype/)
    end

    describe 'architecture_inclusion validation' do
      subject(:download_repository) { create(:download_repository) }

      it {
        expect { download_repository.update!(arch: 's390x') }.to raise_error(
          ActiveRecord::RecordInvalid, 'Validation failed: Architecture has to be available via repository association'
        )
      }
    end
  end
end
