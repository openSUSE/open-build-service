class AddCodeOfConductToConfigurations < ActiveRecord::Migration[7.0]
  def change
    add_column :configurations, :code_of_conduct, :text
  end
end
