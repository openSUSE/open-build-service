class UpdatePacktrackIndex < ActiveRecord::Migration[5.2]

  def up
    remove_index :binary_releases, name: 'exact_search_index'
    add_index :binary_releases, [:binary_name, :binary_epoch, :binary_version,
                                 :binary_release, :binary_arch, :medium,
                                 :on_medium_id, :obsolete_time, :modify_time],
                                name: 'exact_search_index'
  end

  def down
    remove_index :binary_releases, name: 'exact_search_index'
    add_index :binary_releases, [:binary_name, :binary_epoch, :binary_version,
                                 :binary_release, :binary_arch],
                                name: 'exact_search_index'
  end

end
