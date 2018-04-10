# frozen_string_literal: true

class DatetimeNotZeroDefaultNull < ActiveRecord::Migration[4.2]
  def self.up
    execute('alter table packages modify created_at datetime default NULL;')
    execute('alter table packages modify updated_at datetime default NULL;')
    execute('alter table projects modify created_at datetime default NULL;')
    execute('alter table projects modify updated_at datetime default NULL;')
  end

  def self.down
    execute("alter table packages modify created_at datetime default '0000-00-00 00:00:00';")
    execute("alter table packages modify updated_at datetime default '0000-00-00 00:00:00';")
    execute("alter table projects modify created_at datetime default '0000-00-00 00:00:00';")
    execute("alter table projects modify updated_at datetime default '0000-00-00 00:00:00';")
  end
end
