class CreateBsRequests < ActiveRecord::Migration

  def change
    create_table :bs_requests do |t|
      t.string :description
      t.string :creator
      t.string :state
      t.string :comment
      t.string :commenter
      t.integer :superseded_by

      t.timestamps
    end

    add_index :bs_requests, :creator
    add_index :bs_requests, :state
    
    create_table :bs_request_actions do |t|
      t.integer :bs_request_id
      t.string :action_type
      t.string :target_project
      t.string :target_package
      t.string :target_releaseproject
      t.string :source_project
      t.string :source_package
      t.string :source_rev
      t.string :sourceupdate
      t.boolean :updatelink, :default => false
      t.string :person_name
      t.string :group_name
      t.string :role

      t.datetime "created_at"
    end

    create_table :bs_request_histories do |t|
      t.integer :bs_request_id
      t.string :state
      t.string :comment
      t.string :commenter
      t.integer :superseded_by

      t.datetime "created_at"
    end

    create_table :reviews do |t|
      t.integer :bs_request_id
      t.string :creator
      t.string :reviewer
      t.string :reason
      t.string :state
      t.string :by_user
      t.string :by_group
      t.string :by_project
      t.string :by_package

      t.timestamps
    end

    add_index :reviews, :creator
    add_index :reviews, :reviewer
    add_index :reviews, :state
    add_index :reviews, :by_user
    add_index :reviews, :by_group
    add_index :reviews, :by_project
    add_index :reviews, [:by_package, :by_project]

    create_table :bs_request_action_accept_infos do |t|
      t.integer :bs_request_action_id

      t.string :rev
      t.string :srcmd5
      t.string :xsrcmd5
      t.string :osrcmd5
      t.string :oxsrcmd5

      t.datetime "created_at"
    end

    execute("alter table bs_requests collate 'utf8_bin'")
    execute("alter table bs_request_actions collate 'utf8_bin'")
    execute("alter table bs_request_histories collate 'utf8_bin'")

    execute("alter table bs_requests modify comment text")
    execute("alter table bs_requests modify description text")
    execute("alter table reviews modify reason text")
    execute("alter table bs_request_histories modify comment text")
    
    execute("alter table reviews add foreign key (bs_request_id) references bs_requests (id)")
    execute("alter table bs_request_actions add foreign key (bs_request_id) references bs_requests (id)")
    execute("alter table bs_request_histories add foreign key (bs_request_id) references bs_requests (id)")

    execute("alter table bs_request_action_accept_infos add foreign key (bs_request_action_id) references bs_request_actions (id)")

  end
end
