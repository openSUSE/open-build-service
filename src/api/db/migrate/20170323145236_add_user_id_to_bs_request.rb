class AddUserIdToBsRequest < ActiveRecord::Migration[5.0]
  def up
    add_reference(:bs_requests, :user)
    User.all.pluck(:id, :login,).each do |user|
      execute "UPDATE bs_requests SET user_id = '#{user[0]}' WHERE creator = '#{user[1]}'"
    end

    remove_column(:bs_requests, :creator)
  end

  def down
    add_column(:bs_requests, :creator, :string)
    add_index(:bs_requests, :creator)

    User.all.pluck(:id, :login,).each do |user|
      execute "UPDATE bs_requests SET creator = '#{user[1]}' WHERE user_id = '#{user[0]}'"
    end

    remove_reference(:bs_requests, :user)
  end
end
