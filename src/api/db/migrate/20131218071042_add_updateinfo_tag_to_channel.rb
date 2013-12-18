class AddUpdateinfoTagToChannel < ActiveRecord::Migration
  def change
    add_column :channel_targets, :tag, :string
  end
end
