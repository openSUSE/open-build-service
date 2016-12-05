class InitialDatabase < ActiveRecord::Migration
  def self.up
    puts "Please don't use db:migrate to create an initial database."
    puts "Please use \"rake db:setup\" instead!"
    puts "Aborting..."
    1
  end

  def self.down
  end
end
