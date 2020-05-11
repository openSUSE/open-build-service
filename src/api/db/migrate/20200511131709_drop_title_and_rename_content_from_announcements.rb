class DropTitleAndRenameContentFromAnnouncements < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :announcements, :title, :string }
    safety_assured { rename_column :announcements, :content, :message }
  end
end
