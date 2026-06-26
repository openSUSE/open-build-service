RSpec.describe UserYearlyContribution, type: :service do
  let(:user) { create(:user_with_groups) }
  let(:date_for_comment) { Time.zone.now.to_date }
  let(:project) { create(:project, name: 'bob_project', maintainer: [user]) }
  let(:package) { create(:package, name: 'bob_package', project: project) }
  let(:another_package) { create(:package) }
  let(:new_bs_request) do
    create(:bs_request_with_submit_action,
           state: :new,
           creator: user,
           target_project: project,
           target_package: package,
           source_package: another_package)
  end
  let(:comment_for_request) do
    create(:comment_request,
           commentable: new_bs_request,
           user: user,
           updated_at: date_for_comment)
  end

  describe '#call' do
    subject { described_class.new(user, starting_date).call }

    before do
      comment_for_request
    end

    context 'when there is no activity' do
      let(:starting_date) { 1.day.from_now }

      it { expect(subject).to eql({}) }
    end

    context 'when there is some activity' do
      let(:starting_date) { 1.day.ago }

      it { expect(subject).to eql(date_for_comment => 2) }
    end

    context 'when we use times instead of dates' do
      let(:starting_date) { Time.zone.now }

      it { expect(subject).to eql(date_for_comment => 2) }
    end
  end
end
