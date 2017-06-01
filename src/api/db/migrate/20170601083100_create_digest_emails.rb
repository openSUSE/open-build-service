class CreateDigestEmails < ActiveRecord::Migration[5.0]
  def change
    create_table :digest_emails do |t|
      t.references :user
      t.references :group
      t.datetime :sent_at

      t.timestamps
    end
  end
end
