class RenameArchFlagsSelectableAndEnabledToRecommendedAndAvailable < ActiveRecord::Migration
  def self.up
    rename_column :architectures, :enabled, :available
    rename_column :architectures, :selectable, :recommended
    Architecture.reset_column_information
  end

  def self.down
    rename_column :architectures, :available, :enabled
    rename_column :architectures, :recommended, :selectable
    Architecture.reset_column_information
  end
end
