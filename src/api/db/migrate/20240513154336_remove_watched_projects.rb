class RemoveWatchedProjects < ActiveRecord::Migration[7.0]
  def up
    drop_table 'watched_projects', id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'user_id', default: 0, null: false
      t.integer 'project_id', null: false
      t.index ['user_id'], name: 'watched_projects_users_fk_1'
    end
  end

  def down
    create_table 'watched_projects', id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'user_id', default: 0, null: false
      t.integer 'project_id', null: false
      t.index ['user_id'], name: 'watched_projects_users_fk_1'
    end

    add_foreign_key 'watched_projects', 'users', name: 'watched_projects_ibfk_1'
  end
end
