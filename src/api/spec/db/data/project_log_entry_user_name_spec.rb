# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../db/data/20180214132015_project_log_entry_user_name.rb'

RSpec.feature 'ProjectLogEntryUserName', type: :model do
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }

  describe 'up' do
    let!(:entry1) { create(:project_log_entry_comment_for_project, user_name: user.id) }
    let!(:entry2) { create(:project_log_entry_comment_for_package, user_name: other_user.id) }
    let!(:entry5) { create(:project_log_entry_comment_for_package, user_name: User.last.id + 42) }
    before do
      ProjectLogEntryUserName.new.send(:up)
    end

    it 'changes user id to user login' do
      expect(entry1.reload.user_name).to eq(user.login)
      expect(entry2.reload.user_name).to eq(other_user.login)
      expect(entry5.reload.user_name).to eq(User::NOBODY_LOGIN)
    end
  end

  describe 'down' do
    let!(:entry3) { create(:project_log_entry_comment_for_project, user_name: user.login) }
    let!(:entry4) { create(:project_log_entry_comment_for_package, user_name: other_user.login) }
    let!(:entry5) { create(:project_log_entry_comment_for_package, user_name: 'lala') }

    before do
      ProjectLogEntryUserName.new.send(:down)
    end

    it 'changes user login to user id' do
      expect(entry3.reload.user_name).to eq(user.id.to_s)
      expect(entry4.reload.user_name).to eq(other_user.id.to_s)
      expect(entry5.reload.user_name).to eq(User.find_nobody!.id.to_s)
    end
  end
end
