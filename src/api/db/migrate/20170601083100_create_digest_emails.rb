class CreateDigestEmails < ActiveRecord::Migration[5.0]
  def change
    create_table :digest_emails do |t|
      t.references :event_subscription
      t.boolean :email_sent, null: false, default: false

      t.timestamps
    end
  end
end
