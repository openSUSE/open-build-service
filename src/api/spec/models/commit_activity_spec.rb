RSpec.describe CommitActivity do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:package) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:date) }
  end

  describe '.latest_updates' do
    let(:user) { create(:confirmed_user) }
    let(:expected_pairs) do
      [
        %w[ProjectB Package2],
        %w[ProjectA Package1]
      ]
    end

    before do
      CommitActivity.create!(user: user, project: 'ProjectA', package: 'Package1', date: 2.days.ago, count: 1)
      CommitActivity.create!(user: user, project: 'ProjectA', package: 'Package1', date: 1.day.ago, count: 3)
      CommitActivity.create!(user: user, project: 'ProjectB', package: 'Package2', date: Time.zone.today, count: 2)
    end

    it 'returns distinct project and package pairs ordered by most recent date' do
      results = user.commit_activities.latest_updates
      expect(results.map { |r| [r.project, r.package] }).to eq(expected_pairs)
    end

    it 'selects the latest date for each package' do
      latest_a = user.commit_activities.latest_updates.find { |r| r.project == 'ProjectA' }
      expect(latest_a.date.to_date).to eq(1.day.ago.to_date)
    end
  end
end
