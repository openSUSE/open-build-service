class ChangeTextColumns < ActiveRecord::Migration
  def self.up
    # make the mysql datatype the same for all, it mattered what mysql/rails
    # version created the database
    execute("alter table attrib_allowed_values modify value text") 
    execute("alter table attrib_default_values modify value text NOT NULL")
    execute("alter table attrib_values modify value text NOT NULL")
    execute("alter table db_packages modify description text")
    execute("alter table db_projects modify description text")
    execute("alter table delayed_jobs modify handler text")
    execute("alter table delayed_jobs modify last_error text")
    execute("alter table messages modify text text")
    execute("alter table status_messages modify message text")
    execute("alter table user_registrations modify token text NOT NULL")
    execute("alter table users modify adminnote text")
  end

  def self.down
  end
end
