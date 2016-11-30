class CreateDistributions < ActiveRecord::Migration
  def up
    create_table :distributions do |t|
      t.string :vendor, null: false
      t.string :version, null: false
      t.string :name, null: false
      t.string :project, null: false
      t.string :reponame, null: false
      t.string :repository, null: false
      t.string :link
    end

    create_table :distribution_icons do |t|
      t.string :url, null: false
      t.integer :width
      t.integer :height
    end

    # Create JOIN-table
    create_table :distribution_icons_distributions do |t|
      t.integer :distribution_id
      t.integer :distribution_icon_id
    end

    path = Rails.root.join("files", "distributions.xml")
    path = Rails.root.join("files", "distributions.xml.rpmsave") unless File.exist? path
    begin
      req = Xmlhash.parse(File.read(path))
      Distribution.parse(req) if req
    rescue IOError, Errno::ENOENT
    end
  end

  def down
    drop_table :distributions
    drop_table :distribution_icons
    drop_table :distribution_icons_distributions
  end
end
