require 'rails_helper'

RSpec.describe DownloadRepository do

  describe 'validations' do
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:arch) }
    it { is_expected.to validate_presence_of(:repotype) }
    it { is_expected.to validate_presence_of(:repository_id) }
    it { expect(create(:download_repository)).to validate_uniqueness_of(:arch).scoped_to(:repository_id) }
    it { is_expected.to validate_inclusion_of(:repotype).in_array(["rpmmd", "susetags", "deb", "arch", "mdk"]) }
  end
end
