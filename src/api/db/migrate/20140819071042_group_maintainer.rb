# frozen_string_literal: true

class GroupMaintainer < ActiveRecord::Migration[4.2]
  def up
    create_table :group_maintainers do |t|
      t.references :group
      t.references :user
    end

    execute('alter table group_maintainers add foreign key (group_id) references groups(id)')
    execute('alter table group_maintainers add foreign key (user_id) references users(id)')
  end

  def down
    drop_table :group_maintainers
  end
end
