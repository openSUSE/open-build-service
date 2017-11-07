class RenameKiwiPreferenceTypesToKiwiPreferences < ActiveRecord::Migration[5.1]
  def change
    rename_table :kiwi_preference_types, :kiwi_preferences

    rename_column :kiwi_preferences, :image_type, :type_image
    rename_column :kiwi_preferences, :containerconfig_name, :type_containerconfig_name
    rename_column :kiwi_preferences, :containerconfig_tag, :type_containerconfig_tag
  end
end
