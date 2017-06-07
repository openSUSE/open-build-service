class CreateDigestEmailEvents < ActiveRecord::Migration[5.0]
  def change
    create_table :digest_email_events do |t|
      t.integer :digest_email_id, null: false
      t.integer :event_id, null: false
    end
  end
end
