class DropTableGroupsRoles < ActiveRecord::Migration[7.0]
  def change
    drop_table 'groups_roles', id: false, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'group_id', default: 0, null: false
      t.integer 'role_id', default: 0, null: false
      t.datetime 'created_at', precision: nil
      t.index %w[group_id role_id], name: 'groups_roles_all_index', unique: true
      t.index ['role_id'], name: 'role_id'
    end
  end
end
