class AddChannelDisableFlag < ActiveRecord::Migration[6.0]
  def change
    add_column :channels, :disabled, :boolean
  end
end
