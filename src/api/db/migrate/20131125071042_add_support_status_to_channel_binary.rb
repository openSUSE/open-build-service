class AddSupportStatusToChannelBinary < ActiveRecord::Migration
  def change
    add_column :channel_binaries, :supportstatus, :string
  end
end
