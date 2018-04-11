# frozen_string_literal: true

class AddUpdateinfoTracking < ActiveRecord::Migration[4.2]
  def up
    create_table :updateinfos do |t|
      t.references :repository, null: false
      t.references :package,    null: false
      t.datetime :created_at, null: false
      t.string :identifier, null: false
    end

    add_index :updateinfos, :identifier
    add_index :updateinfos, [:repository_id, :package_id]
    execute('alter table updateinfos add FOREIGN KEY (repository_id) references repositories(id)')
    execute('alter table updateinfos add FOREIGN KEY (package_id) references packages(id)')
  end

  def down
    drop_table :updateinfos
  end
end
