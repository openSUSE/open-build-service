# frozen_string_literal: true
class ProjectLogEntryUserName < ActiveRecord::Migration[5.1]
  def up
    ProjectLogEntry.where('event_type like "%comment_for%"').in_batches do |batch|
      batch.each do |log_entry|
        user = User.find_by(id: log_entry.user_name).try(:login)
        user ||= User::NOBODY_LOGIN
        log_entry.update_attributes(user_name: user)
      end
    end
  end

  def down
    ProjectLogEntry.where('event_type like "%comment_for%"').in_batches do |batch|
      batch.each do |log_entry|
        user = User.find_by(login: log_entry.user_name).try(:id)
        user ||= User.find_nobody!.try(:id)
        log_entry.update_attributes(user_name: user)
      end
    end
  end
end
