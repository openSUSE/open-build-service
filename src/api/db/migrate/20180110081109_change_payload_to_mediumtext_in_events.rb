class ChangePayloadToMediumtextInEvents < ActiveRecord::Migration[5.1]
  def change
    change_column :events, :payload, :mediumtext
  end
end
