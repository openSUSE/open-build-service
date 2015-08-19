class AddForeignKeys < ActiveRecord::Migration
  def up
    # these are broken
    Comment.where('user_id = 0').delete_all
    execute("alter table comments add foreign key (user_id) references users (id)")
    execute("alter table comments add foreign key (package_id) references packages (id)")
    execute("alter table comments add foreign key (project_id) references projects (id)")
  end

  def down
   # noone cares
  end
end
