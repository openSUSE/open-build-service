class CreateDigestEmails < ActiveRecord::Migration[5.0]
  def change
    create_table :digest_emails do |t|
      t.references :event_subscription, null: false
      t.boolean :email_sent, default: false
      t.text :body_text
      t.text :body_html

      t.timestamps
    end
  end
end
