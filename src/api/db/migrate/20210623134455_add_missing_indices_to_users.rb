class AddMissingIndicesToUsers < ActiveRecord::Migration[6.0]
  def change
    add_index(:users, :in_beta)
    add_index(:users, :in_rollout)
  end
end
