class CreateDistributions < ActiveRecord::Migration
  def up
    
    unless table_exists?("distributions")
      create_table :distributions do |t|
        t.string :vendor, null: false
        t.string :version, null: false
        t.string :name, null: false
        t.string :project, null: false
        t.string :reponame, null: false
        t.string :repository, null: false
        t.string :link
      end
    end

    unless table_exists?("distribution_icons")
      create_table :distribution_icons do |t|
        t.string :url, null: false
        t.integer :width
        t.integer :height
      end
    end

    # Create JOIN-table
    unless table_exists?("distribution_icons_distributions")
      create_table :distribution_icons_distributions do |t|
        t.integer :distribution_id
        t.integer :distribution_icon_id
      end
    end

    path = Rails.root.join("files", "distributions.xml")
    if File.exists?(path)
      begin
        req = Xmlhash.parse(File.read(path))
        if req
          Distribution.parse(req)
        end
      rescue IOError
      end
    end
  end

  def down
    drop_table :distributions
    drop_table :distribution_icons
    drop_table :distribution_icons_distributions
  end
end
