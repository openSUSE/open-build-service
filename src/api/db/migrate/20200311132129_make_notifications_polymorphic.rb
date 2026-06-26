class MakeNotificationsPolymorphic < ActiveRecord::Migration[5.2]
  def change
    add_reference :notifications, :notifiable, polymorphic: true, type: :integer, index: true
    add_column :notifications, :bs_request_oldstate, :string, collation: 'utf8_unicode_ci'
  end
end
