require "rails_helper"

RSpec.describe DownloadRepository do
  describe "validations" do
    subject(:download_repository) { create(:download_repository) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:arch) }
    it { is_expected.to validate_presence_of(:repotype) }
    it { is_expected.to validate_presence_of(:repository_id) }
    it { is_expected.to validate_uniqueness_of(:arch).scoped_to(:repository_id) }
    it { is_expected.to validate_inclusion_of(:repotype).in_array(["rpmmd", "susetags", "deb", "arch", "mdk"]) }

    describe "architecture_inclusion validation" do
      subject(:download_repository) { create(:download_repository) }
      it {
        expect { download_repository.update_attributes!(arch: "s390x") }.to raise_error(
          ActiveRecord::RecordInvalid, "Validation failed: Architecture has to be available via repository association"
        )
      }
    end
  end
end
