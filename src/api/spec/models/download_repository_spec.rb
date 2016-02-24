require "rails_helper"

RSpec.describe DownloadRepository do
  describe "validations" do
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:arch) }
    it { is_expected.to validate_presence_of(:repotype) }
    it { is_expected.to validate_presence_of(:repository_id) }
    it { expect(create(:download_repository)).to validate_uniqueness_of(:arch).scoped_to(:repository_id) }
    it { is_expected.to validate_inclusion_of(:repotype).in_array(["rpmmd", "susetags", "deb", "arch", "mdk"]) }

    it "validates that architecture is supported by scheduler" do
      # FIXME: This is required because of seeding our test DB
      architectures = Architecture.all.pluck(:name)
      is_expected.to validate_inclusion_of(:arch).in_array(architectures)
    end
  end
end
