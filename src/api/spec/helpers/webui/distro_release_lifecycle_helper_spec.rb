RSpec.describe Webui::DistroReleaseLifecycleHelper do
  describe '#lifecycle_status_class' do
    it 'maps general_availability to the success color' do
      expect(lifecycle_status_class('general_availability')).to eq('text-bg-success')
    end

    it 'maps maintenance and extended_support to the primary color' do
      expect(lifecycle_status_class('maintenance')).to eq('text-bg-primary')
      expect(lifecycle_status_class('extended_support')).to eq('text-bg-primary')
    end

    it 'maps development, alpha, beta and release_candidate to the info color' do
      %w[development alpha beta release_candidate].each do |status|
        expect(lifecycle_status_class(status)).to eq('text-bg-info')
      end
    end

    it 'maps deprecated to the warning color' do
      expect(lifecycle_status_class('deprecated')).to eq('text-bg-warning')
    end

    it 'maps end_of_life to the danger color' do
      expect(lifecycle_status_class('end_of_life')).to eq('text-bg-danger')
    end

    it 'maps any other status to the secondary color' do
      expect(lifecycle_status_class('planned')).to eq('text-bg-secondary')
    end
  end

  describe '#distro_release_timeline_groups' do
    let(:leap) { build_stubbed(:distro_release, name: 'Leap 15.6') }
    let(:tumbleweed) { build_stubbed(:distro_release, name: 'Tumbleweed') }

    it 'maps each distro release to an id/content pair using its name and position' do
      expect(distro_release_timeline_groups([leap, tumbleweed])).to eq(
        [{ id: leap.id, content: 'Leap 15.6', order: 0 }, { id: tumbleweed.id, content: 'Tumbleweed', order: 1 }]
      )
    end
  end

  describe '#distro_release_timeline_items' do
    subject { distro_release_timeline_items([distro_release]) }

    let(:distro_release) { create(:distro_release) }

    context 'when a distro release has no lifecycles' do
      it 'returns no items for it' do
        expect(subject).to eq([])
      end
    end

    context 'when a distro release has a single, ongoing lifecycle' do
      let!(:lifecycle) do
        create(:distro_release_lifecycle, distro_release: distro_release, name: 'GA',
                                          status: :general_availability, date: Date.current)
      end

      let(:item) { subject.first }

      it 'builds a single open-ended item colored by its status' do
        expect(subject.size).to eq(1)
        expect(item).to include(id: lifecycle.id, group: distro_release.id, start: lifecycle.date,
                                end: Date.current + 1.year, status: 'general_availability',
                                className: 'distro-release-lifecycle-general-availability text-bg-success')
      end

      it 'renders the lifecycle name and status in the content and title' do
        expect(item[:content]).to include('GA', 'fw-semibold')
        expect(item[:title]).to include('GA', 'General Availability')
      end
    end

    context 'when a distro release has multiple lifecycles out of chronological order' do
      let!(:ga) do
        create(:distro_release_lifecycle, distro_release: distro_release, name: 'GA',
                                          status: :general_availability, date: 10.days.ago.to_date)
      end

      let!(:eol) do
        create(:distro_release_lifecycle, distro_release: distro_release, name: 'EOL',
                                          status: :end_of_life, date: 10.days.from_now.to_date)
      end

      let(:ga_item) { subject.first }
      let(:eol_item) { subject.second }

      it 'sorts them by date and closes the general availability phase at the start of the next one' do
        expect(ga_item).to include(id: ga.id, group: distro_release.id, start: ga.date, end: eol.date,
                                   status: 'general_availability',
                                   className: 'distro-release-lifecycle-general-availability text-bg-success')
      end

      it 'mentions the lifecycle name and upcoming end of life in the content and title' do
        expect(ga_item[:content]).to include('GA')
        expect(ga_item[:title]).to include('GA', 'End of Life on')
      end

      it 'renders the end of life phase as a marker instead of a phase of its own' do
        expect(eol_item).to include(id: eol.id, group: distro_release.id, type: 'box', content: '', start: eol.date,
                                    status: 'end_of_life',
                                    className: 'distro-release-lifecycle-eol distro-release-lifecycle-end-of-life')
      end

      it 'mentions the lifecycle name and status in the marker title' do
        expect(eol_item[:title]).to include('EOL', 'End of Life')
      end
    end

    context 'when there are multiple distro releases' do
      subject { distro_release_timeline_items([leap, tumbleweed]) }

      let(:leap) { create(:distro_release, name: 'leap') }
      let(:tumbleweed) { create(:distro_release, name: 'tumbleweed') }
      let!(:leap_lifecycle) { create(:distro_release_lifecycle, distro_release: leap, date: Date.current) }
      let!(:tumbleweed_lifecycle) { create(:distro_release_lifecycle, distro_release: tumbleweed, date: Date.current) }

      it 'groups the items under their own distro release id' do
        expect(subject.pluck(:group)).to contain_exactly(leap.id, tumbleweed.id)
        expect(subject.pluck(:id)).to contain_exactly(leap_lifecycle.id, tumbleweed_lifecycle.id)
      end
    end

    context 'when the latest lifecycle date is in the past' do
      let(:distro_release) { create(:distro_release) }
      let!(:lifecycle) { create(:distro_release_lifecycle, distro_release: distro_release, date: 10.days.ago.to_date) }

      it 'uses today plus a year as the open end date' do
        expect(subject.last[:end]).to eq(Date.current + 1.year)
        expect(lifecycle.date).to be < Date.current
      end
    end
  end

  describe '#distro_release_timeline_legend' do
    subject { distro_release_timeline_legend([distro_release]) }

    let(:distro_release) { create(:distro_release) }

    let!(:lifecycle) do
      create(:distro_release_lifecycle, distro_release: distro_release, status: :general_availability)
    end

    it 'lists every defined status' do
      expect(subject.size).to eq(DistroReleaseLifecycle.statuses.size)
    end

    it 'marks a present status with its label, highlight class and color' do
      entry = subject.find { |e| e[:status] == 'general_availability' }
      expect(entry).to eq(status: 'general_availability', label: 'General Availability',
                          highlight_class: 'distro-release-lifecycle-general-availability',
                          color_class: 'text-bg-success', present: true)
    end

    it 'marks an absent status as not present' do
      entry = subject.find { |e| e[:status] == 'planned' }
      expect(entry).to eq(status: 'planned', label: 'Planned', highlight_class: 'distro-release-lifecycle-planned',
                          color_class: 'text-bg-secondary', present: false)
    end
  end
end
