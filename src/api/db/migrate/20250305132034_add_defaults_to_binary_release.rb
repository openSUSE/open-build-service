class AddDefaultsToBinaryRelease < ActiveRecord::Migration[7.0]
  def change
    change_column_default :binary_releases, :binary_release, from: nil, to: '0'
    change_column_default :binary_releases, :binary_version, from: nil, to: '0'
  end
end
