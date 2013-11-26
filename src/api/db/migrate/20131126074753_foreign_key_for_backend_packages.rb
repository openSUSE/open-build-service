class ForeignKeyForBackendPackages < ActiveRecord::Migration
  def change
    execute('delete from backend_packages where package_id not in (select id from packages)')
    execute('alter table backend_packages add FOREIGN KEY (package_id) references packages (id)')
    execute('delete from backend_packages where links_to_id not in (select id from packages)')
    execute('alter table backend_packages add FOREIGN KEY (links_to_id) references packages (id)')
  end
end
