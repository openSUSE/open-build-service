class ChangeEventsPayloadFromTextToMediumtext < ActiveRecord::Migration[7.0]
  def self.up
    safety_assured { change_column :events, :payload, :text, limit: 16.megabytes - 1 }
  end

  def self.down
    # NOTE: change back to TEXT could cut some payloads that could be more than 65535 characters.
    # From TEXT to MEDIUMTEXT we could store from ~64kb to ~16Mb of data but basically nothing has
    # a payload more than ~64kb so the event payload nearly should be always around 64kb.
  end
end
