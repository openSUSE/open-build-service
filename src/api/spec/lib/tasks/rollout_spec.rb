# rubocop:disable RSpec/DescribeClass
RSpec.describe 'rollout' do
  # rubocop:enable RSpec/DescribeClass
  include_context 'rake'
  let!(:rollout_user) { create(:confirmed_user) }
  let!(:non_rollout_user) { create(:confirmed_user, in_rollout: false) }
  let!(:in_rollout_in_beta_user) { create(:confirmed_user, :in_beta) }
  let!(:non_rollout_in_beta_user) { create(:confirmed_user, :in_beta, in_rollout: false) }
  let!(:in_rollout_in_group_user) { create(:user_with_groups) }
  let!(:non_rollout_in_group_user) { create(:user_with_groups, in_rollout: false) }
  let!(:non_recently_logged_user) do
    user = create(:confirmed_user, in_rollout: false)
    user.last_logged_in_at = Time.zone.today.prev_year
    user.save!
  end
  let(:all_in_rollout_users) { User.where(in_rollout: true) }

  before do
    freeze_time
  end

  after do
    unfreeze_time
  end

  describe 'all_on' do
    let(:task) { 'rollout:all_on' }

    it 'moves all the users to Rollout Program' do
      expect { rake_task.invoke }.to change(User.where(in_rollout: true), :count).from(3).to(7)
    end
  end

  describe 'all_off' do
    let(:task) { 'rollout:all_off' }

    it 'moves all the users out of Rollout Program' do
      expect { rake_task.invoke }.to change(User.where(in_rollout: false), :count).from(4).to(7)
    end
  end

  describe 'from_beta' do
    let(:task) { 'rollout:from_beta' }
    let(:users) { User.where(in_beta: true) }

    it 'moves all the users in Beta Program to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(2)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end

  describe 'recently_logged_users' do
    let(:task) { 'rollout:recently_logged_users' }
    let(:users) { User.where(last_logged_in_at: Time.zone.today.prev_month(3)..Time.zone.today) }

    it 'moves all recently logged users to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(3).to(6)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(6) }
  end

  describe 'non_recently_logged_users' do
    let(:task) { 'rollout:non_recently_logged_users' }
    let(:users) { User.where.not(last_logged_in_at: Time.zone.today.prev_month(3)..Time.zone.today) }

    it 'moves all non-recently-logged users to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(0).to(1)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end

  describe 'from_groups' do
    let(:task) { 'rollout:from_groups' }
    let(:users) { User.joins(:groups_users).distinct }

    it 'moves all the users from groups to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(2)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end

  context 'with Staff users' do
    let!(:staff_user1) { create(:staff_user, in_rollout: false) }
    let!(:staff_user2) { create(:staff_user, in_rollout: false) }
    let!(:staff_user3) { create(:staff_user) }
    let(:users) { User.staff }

    describe 'staff_on' do
      let(:task) { 'rollout:staff_on' }

      it 'moves all Staff users to Rollout Program' do
        expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(3)
      end

      it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(4).to(6) }
    end

    describe 'staff_off' do
      let(:task) { 'rollout:staff_off' }

      it 'moves all Staff users out of Rollout Program' do
        expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(0)
      end

      it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(4).to(3) }
    end
  end

  context 'with anonymous user' do
    describe 'anonymous_on' do
      let!(:anonymous_user) { create(:user_nobody, in_rollout: false) }
      let(:task) { 'rollout:anonymous_on' }

      it 'moves the anonymous user to Rollout Program' do
        expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4)
      end
    end

    describe 'anonymous_off' do
      let!(:anonymous_user) { create(:user_nobody, in_rollout: true) }
      let(:task) { 'rollout:anonymous_off' }

      it 'moves anonymous user out of Rollout Program' do
        expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(4).to(3)
      end
    end
  end
end
