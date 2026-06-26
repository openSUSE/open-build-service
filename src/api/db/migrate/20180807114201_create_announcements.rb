class CreateAnnouncements < ActiveRecord::Migration[5.2]
  def change
    create_table :announcements, id: :integer, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.string :title
      t.text :content

      t.timestamps
    end

    create_table :announcements_users, id: false, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.belongs_to :user, index: true, type: :integer
      t.belongs_to :announcement, index: true, type: :integer

      t.timestamps
    end
  end
end
