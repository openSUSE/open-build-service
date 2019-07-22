# typed: false
require 'rails_helper'

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
    user.last_logged_in_at = Time.now - 1.year
    user.save!
  end

  let(:all_in_rollout_users) { User.where(in_rollout: true) }

  describe 'all_on' do
    let(:task) { 'rollout:all_on' }

    it 'will move all the users to Rollout Program' do
      expect { rake_task.invoke }.to change(User.where(in_rollout: true), :count).from(3).to(7)
    end
  end

  describe 'all_off' do
    let(:task) { 'rollout:all_off' }

    it 'will move all the users out of Rollout Program' do
      expect { rake_task.invoke }.to change(User.where(in_rollout: false), :count).from(4).to(7)
    end
  end

  describe 'from_beta' do
    let(:task) { 'rollout:from_beta' }
    let(:users) { User.where(in_beta: true) }

    it 'will move all the users in Beta Program to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(2)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end

  describe 'from_groups' do
    let(:task) { 'rollout:from_groups' }
    let(:users) { User.joins(:groups_users).distinct }

    it 'will move all the users from groups to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(1).to(2)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end

  describe 'recently_logged_users' do
    let(:task) { 'rollout:recently_logged_users' }
    let(:users) { User.where(last_logged_in_at: 3.months.ago.midnight..Time.zone.now) }

    it 'will move all recently logged users to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(3).to(6)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(6) }
  end

  describe 'non_recently_logged_users' do
    let(:task) { 'rollout:non_recently_logged_users' }
    let(:users) { User.where.not(last_logged_in_at: 3.months.ago.midnight..Time.zone.now) }

    it 'will move all non-recently-logged users to Rollout Program' do
      expect { rake_task.invoke }.to change(users.where(in_rollout: true), :count).from(0).to(1)
    end

    it { expect { rake_task.invoke }.to change(all_in_rollout_users, :count).from(3).to(4) }
  end
end
