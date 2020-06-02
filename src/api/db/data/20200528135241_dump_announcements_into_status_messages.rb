class DumpAnnouncementsIntoStatusMessages < ActiveRecord::Migration[6.0]
  class DummyAnnouncement < ApplicationRecord
    self.table_name = 'announcements'
    has_and_belongs_to_many :users, class_name: 'DummyUser', foreign_key: 'announcement_id', association_foreign_key: 'user_id'
  end

  class DummyUser < ApplicationRecord
    self.table_name = 'users'
    has_and_belongs_to_many :announcements, class_name: 'DummyAnnouncement', foreign_key: 'user_id', association_foreign_key: 'announcement_id'
  end

  def up
    DummyAnnouncement.all.each do |dummy_announcement|
      sm = StatusMessage.create(message: dummy_announcement.content, severity: 'announcement', communication_scope: 'all_users', user: User.admins.first)
      sm.users << User.where(id: dummy_announcement.users.pluck(:id))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
