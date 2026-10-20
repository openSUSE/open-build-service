RSpec.describe DistroReleaseLifecycle do
  let(:distro_release) { create(:distro_release) }
  let(:lifecycle) { create(:distro_release_lifecycle, distro_release: distro_release) }

  describe 'validations' do
    it 'rejects a name already taken in the same release' do
      expect(build(:distro_release_lifecycle, distro_release: distro_release, name: lifecycle.name)).not_to be_valid
    end

    it 'allows the same name in a different release' do
      expect(build(:distro_release_lifecycle, name: lifecycle.name)).to be_valid
    end

    it 'rejects an unknown status' do
      expect(build(:distro_release_lifecycle, status: 'unknown')).not_to be_valid
    end
  end

  describe '.chronological' do
    let!(:end_of_life) { create(:distro_release_lifecycle, distro_release: distro_release, date: Date.new(2030, 1, 1), status: :end_of_life) }
    let!(:beta) { create(:distro_release_lifecycle, distro_release: distro_release, date: Date.new(2026, 1, 1), status: :beta) }
    let!(:general_availability) do
      create(:distro_release_lifecycle, distro_release: distro_release, date: Date.new(2026, 6, 1), status: :general_availability)
    end

    it 'orders the lifecycles by date, earliest first' do
      expect(distro_release.distro_release_lifecycles.chronological).to eq([beta, general_availability, end_of_life])
    end
  end

  describe '#status_label' do
    it 'uses the custom label when there is one' do
      expect(build(:distro_release_lifecycle, status: :end_of_life).status_label).to eq('End of Life')
    end

    it 'humanizes the status otherwise' do
      expect(build(:distro_release_lifecycle, status: :beta).status_label).to eq('Beta')
    end
  end
end
