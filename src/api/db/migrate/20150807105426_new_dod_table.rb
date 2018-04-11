# frozen_string_literal: true

class NewDodTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :download_repositories do |t|
      t.references :repository, null: false
      t.string :arch,       null: false
      t.string :url,        null: false
      t.string :repotype
      t.string :archfilter
      t.string :masterurl
      t.string :mastersslfingerprint
      t.text :pubkey
    end
    execute('alter table download_repositories add foreign key (repository_id) references repositories(id)')

    # just drop, do not migrate. it was broken and unsupported before.
    drop_table :downloads
  end

  def self.down
    drop_table :download_repositories

    create_table :downloads do |t|
      t.references :project
      t.references :architecture
      t.string :baseurl
      t.string :metafile
      t.string :mtype
    end
  end
end
