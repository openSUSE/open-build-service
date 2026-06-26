class AddContactNameAndContactUrlToConfigurations < ActiveRecord::Migration[7.0]
  def change
    add_column :configurations, :contact_name, :string
    add_column :configurations, :contact_url, :string
  end
end
