class OneMoreConstraintForComments < ActiveRecord::Migration
  def change
    execute("alter table comments add FOREIGN KEY (parent_id) references comments (id)")
  end
end
