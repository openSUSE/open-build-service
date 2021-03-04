require 'rails_helper'

RSpec.describe Webui::UserHelper do
  let!(:creator) { create(:confirmed_user, login: 'Adrian') }
  let(:date) { Time.zone.now.to_date }

  describe '#user_with_realname_and_icon' do
    skip('Please add some tests')
  end

  describe '#requester_str' do
    let(:requester) { create(:user, login: 'Ana') }

    it 'do not show the requester if they are the same as the creator' do
      expect(requester_str(creator.login, creator.login, nil)).to be(nil)
    end

    it 'show the requester if they are different from the creator' do
      expect(requester_str(creator.login, requester.login, nil)).to include('user', requester.login)
    end

    it 'show the group' do
      expect(requester_str(creator.login, nil, 'ana-team')).to include('group', 'ana-team')
    end
  end

  describe '#activity_date_commits' do
    let(:activities) { UserDailyContribution.new(creator, date).call }
    let(:project) { create(:project, name: 'bob_project', maintainer: [creator]) }
    let(:package) { create(:package, name: 'bob_package', project: project) }
    let(:commit_activity) do
      CommitActivity.create(user: creator,
                            date: date,
                            project: project,
                            package: package,
                            count: 1)
    end

    context 'when there is only one project and only one package' do
      before do
        commit_activity
      end

      it 'renders a line with 1 commit' do
        expect(activity_date_commits(activities[:commits])).to match(/1 commit in/)
      end

      it 'renders a line with the commit for the project' do
        expect(activity_date_commits(activities[:commits])).to match(project.name)
      end
    end

    context 'when there is only one project but there are two packages' do
      let(:second_package) { create(:package, name: 'chad_package', project: project) }
      let(:second_source_package) { create(:package) }
      let(:second_commit_activity) do
        CommitActivity.create(user: creator,
                              date: date,
                              project: project,
                              package: second_package,
                              count: 1)
      end

      before do
        commit_activity
        second_commit_activity
      end

      it 'renders a line with 2 commit' do
        expect(activity_date_commits(activities[:commits])).to match(/2 commits in/)
      end

      it 'renders a line with the commit for the project' do
        expect(activity_date_commits(activities[:commits])).to match(project.name)
      end
    end

    context 'when there are two projects and there is only one package' do
      let(:second_project) { create(:project, name: 'chad_project', maintainer: [creator]) }
      let(:second_package) { create(:package, name: 'chad_package', project: second_project) }
      let(:second_commit_activity) do
        CommitActivity.create(user: creator,
                              date: date,
                              project: second_project,
                              package: second_package,
                              count: 1)
      end

      before do
        commit_activity
        second_commit_activity
      end

      it 'renders a line with 1 commit' do
        expect(activity_date_commits(activities[:commits])).to match(/1 commit in/)
      end

      it 'renders a line with the commit for the first project' do
        expect(activity_date_commits(activities[:commits])).to match("#{project.name} / #{package.name}")
      end

      it 'renders a line with the commit for the second project' do
        expect(activity_date_commits(activities[:commits])).to match("#{second_project.name} / #{second_package.name}")
      end
    end
  end
end
