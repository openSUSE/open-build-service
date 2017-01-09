class AddAuthorizationTokenToPackages < ActiveRecord::Migration
  def self.up
    create_table :tokens do |t|
      t.string :string
      t.integer :user_id, null: false
      t.belongs_to :package
    end
    add_index :tokens, [:string], unique: true
    execute("alter table tokens add FOREIGN KEY (user_id) references users (id);")
    execute("alter table tokens add FOREIGN KEY (package_id) references packages (id);")
  end

  def self.down
    drop_table :tokens
  end
end
