class AddDownload < ActiveRecord::Migration
  def self.up
    create_table :downloads do |t|
      t.string :baseurl
      t.string :metafile
      t.string :mtype
      t.integer :architecture_id
      t.integer :db_project_id
    end
  end

  def self.down
    drop_table "downloads"
  end
end
