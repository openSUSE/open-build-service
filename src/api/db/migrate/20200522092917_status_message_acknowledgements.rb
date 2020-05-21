class StatusMessageAcknowledgements < ActiveRecord::Migration[6.0]
  def change
    create_table :status_message_acknowledgements, id: :integer do |t|
      t.belongs_to :status_message, index: true, type: :integer
      t.belongs_to :user, index: true, type: :integer

      t.timestamps
    end
  end
end
