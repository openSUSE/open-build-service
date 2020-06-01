class DumpAnnouncementsIntoStatusMessages < ActiveRecord::Migration[6.0]
  def up
    Announcement.all.each do |announcement|
      sm = StatusMessage.create(message: announcement.content, severity: 'announcement', communication_scope: 'all_users', user: User.admins.first)
      sm.users << announcement.users
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
