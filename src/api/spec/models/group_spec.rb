RSpec.describe Group do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }
  let(:another_user) { create(:confirmed_user, login: 'eisenilse') }

  describe 'validations' do
    it { is_expected.to validate_length_of(:title).is_at_least(2).with_message('must have more than two characters') }
    it { is_expected.to validate_length_of(:title).is_at_most(100).with_message('must have less than 100 characters') }
  end

  describe '#add_user' do
    context 'when the user is already in the group' do
      before do
        group.users << user
      end

      it 'does nothing' do
        expect { group.add_user(user) }.not_to change(GroupsUser, :count)
      end
    end

    context 'when a race condition occurs' do
      before do
        allow(GroupsUser).to receive(:exists?).with(user: user, group: group).and_return(false, true)
        allow(GroupsUser).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'handles it gracefully' do
        expect { group.add_user(user) }.not_to raise_error
      end
    end
  end

  describe '#replace_members' do
    subject! { group.replace_members(members) }

    context 'no previous group users' do
      context 'adding one valid user' do
        let(:members) { user.login }

        it 'adds one user successfully' do
          expect(subject).to be_truthy
          expect(group.users).to eq([user])
        end
      end

      context 'adding two valid users' do
        let(:members) { "#{user.login},#{another_user.login}" }

        it 'adds more than one user successfully' do
          expect(subject).to be_truthy
          expect(group.users).to eq([user, another_user])
        end
      end

      context 'with user _nobody_' do
        let(:members) { create(:user_nobody).login }

        it 'does not add the user' do
          expect(subject).to be_falsey
          expect(group.users).to eq([])
          expect(group.errors.full_messages).to eq(["Validation failed: Couldn't find user _nobody_"])
        end
      end
    end

    context 'one previous group user' do
      before do
        group.users << user
      end

      context 'with an invalid user' do
        let(:members) { 'Foobar' }

        it 'errors and does not change users' do
          expect(subject).to be_falsey
          expect(group.users).to eq([user])
          expect(group.errors.full_messages).to eq(["Couldn't find User"])
        end
      end

      context 'with two users, one of them invalid' do
        let(:members) { "#{another_user.login},Foobar" }

        it 'errors and does not change users' do
          expect(subject).to be_falsey
          expect(group.users).to eq([user])
          expect(group.errors.full_messages).to eq(["Couldn't find User"])
        end
      end
    end
  end

  describe '#involved_projects' do
    let!(:involved_project) { create(:project, maintainer: group) }

    it { expect(group.involved_projects).to contain_exactly(involved_project) }
  end

  describe '#involved_packages' do
    let!(:involved_package) { create(:package_with_maintainer, maintainer: group) }
    let!(:involved_project) { create(:project_with_package, package_name: 'blah', maintainer: group) }

    it { expect(group.involved_packages).to contain_exactly(involved_package) }
  end

  describe '#bs_requests' do
    let(:involved_project) { create(:project, maintainer: group) }
    let!(:incoming_request) { create(:bs_request_with_submit_action, target_project: involved_project, description: 'incoming') }
    let!(:outgoing_request) { create(:bs_request_with_submit_action, source_project: involved_project, description: 'outgoing') }
    let!(:request_with_group_review) { create(:delete_bs_request, target_project: create(:project), review_by_group: group, description: 'group_review') }
    let!(:request_with_project_review) { create(:delete_bs_request, target_project: create(:project), review_by_project: involved_project, description: 'project_review') }
    let!(:request_with_package_review) do
      create(:delete_bs_request, target_project: create(:project), review_by_package: create(:package_with_maintainer, maintainer: group), description: 'package_review')
    end
    let!(:unrelated_request) { create(:bs_request_with_submit_action, source_project: create(:project), description: 'unrelated') }

    it { expect(group.bs_requests.pluck(:description)).to contain_exactly('incoming', 'outgoing', 'group_review', 'project_review', 'package_review') }
  end
end
