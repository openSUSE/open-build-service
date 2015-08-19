class EnlargeErrorColumn < ActiveRecord::Migration
  def up
    change_column :backend_packages, :error, :text
  end

  def down
    change_column :backend_packages, :error, :string
  end
end
