RSpec.describe DistroRelease do
  let(:distro_release) { create(:distro_release) }

  describe '#current_lifecycle and #next_lifecycle' do
    let!(:general_availability) { create(:distro_release_lifecycle, distro_release: distro_release, name: 'GA', date: 1.month.ago) }
    let!(:end_of_life) do
      create(:distro_release_lifecycle, distro_release: distro_release, name: 'EOL', date: 1.year.from_now, status: :end_of_life)
    end

    before do
      create(:distro_release_lifecycle, distro_release: distro_release, name: 'Beta', date: 2.months.ago, status: :beta)
      create(:distro_release_lifecycle, distro_release: distro_release, name: 'Extended', date: 2.years.from_now, status: :extended_support)
    end

    it 'returns the latest lifecycle which already started' do
      expect(distro_release.current_lifecycle).to eq(general_availability)
    end

    it 'returns the upcoming lifecycle' do
      expect(distro_release.next_lifecycle).to eq(end_of_life)
    end
  end

  context 'without lifecycles' do
    it { expect(distro_release.current_lifecycle).to be_nil }
    it { expect(distro_release.next_lifecycle).to be_nil }
  end
end
