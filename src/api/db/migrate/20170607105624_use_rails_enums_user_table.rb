class UseRailsEnumsUserTable < ActiveRecord::Migration[5.0]
  def up
    User.transaction do
      change_table(:users) do |t|
        t.column :new_state, :integer, limit: 2, default: 0
      end

      User.where(state: 'unconfirmed').update_all(new_state: 0)
      User.where(state: 'confirmed').update_all(new_state: 1)
      User.where(state: 'locked').update_all(new_state: 2)
      User.where(state: 'deleted').update_all(new_state: 3)
      User.where(state: 'subaccount').update_all(new_state: 4)

      remove_column :users, :state
      rename_column :users, :new_state, :state
    end
  end

  def down
    User.transaction do
      change_table(:users) do |t|
        t.column :new_state, :string, limit: 11, default: 'unconfirmed'
      end

      User.where(state: 0).update_all(new_state: 'unconfirmed')
      User.where(state: 1).update_all(new_state: 'confirmed')
      User.where(state: 2).update_all(new_state: 'locked')
      User.where(state: 3).update_all(new_state: 'deleted')
      User.where(state: 4).update_all(new_state: 'subaccount')

      remove_column :users, :state
      rename_column :users, :new_state, :state
    end
  end
end
