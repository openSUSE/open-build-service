class ProjectLogEntryUserName < ActiveRecord::Migration[5.1]
  def up
    ProjectLogEntry.where('event_type like "%comment_for%"').in_batches do |log_entry|
      user = User.find_by(id: log_entry.user_name).try(:login)
      user ||= User::NOBODY_LOGIN
      # rubocop:disable Rails/SkipsModelValidations
      log_entry.update_attribute(user_name: user)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def down
    ProjectLogEntry.where('event_type like "%comment_for%"').in_batches do |log_entry|
      user = User.find_by(id: log_entry.user_name).try(:id)
      user ||= User.find_nobody!.try(:id)
      # rubocop:disable Rails/SkipsModelValidations
      log_entry.update_attribute(user_name: user)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
