class AddTosurlToConfiguration < ActiveRecord::Migration[6.1]
  def change
    add_column :configurations, :tos_url, :string
  end
end
