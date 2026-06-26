class AddUniqueIndexOnDecisionIdFieldOnAppealsTable < ActiveRecord::Migration[7.2]
  def change
    add_index :appeals, %i[decision_id appellant_id], unique: true, name: 'index_appeals_on_decision_id'
    # we remove the old non-unique index that clashes with the previous one
    remove_index :appeals, :decision_id, name: 'fk_rails_5fe229ec9a', if_exists: true
  end
end
