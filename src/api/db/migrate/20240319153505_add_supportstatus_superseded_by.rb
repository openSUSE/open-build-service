class AddSupportstatusSupersededBy < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_binaries, :superseded_by, :string
  end
end
