require 'fileutils'

module ActiveRecord # :nodoc:

  # These functions will save and restore data for a single table, into a fixture file.
  # The fixtures are kept under <tt>#{RAILS_ROOT}/db/data/#{RAILS_ENV}/</tt>, and can then be
  # version controlled (via svn, cvs, etc).
  # 
  # === Example
  # 
  # Let's say we create a posts table...
  # 
  # <tt>db/migration/001_posts_table.rb:</tt>
  #   class PostsTable < ActiveRecord::Migration
  #     def self.up
  #       create_table "posts", :force => true do |t|
  #         t.column "title", :string, :default => "", :null => false
  #         t.column "text", :text, :default => "", :null => false
  #       end
  # 
  #       restore_table_from_fixture("posts")
  #     end
  # 
  #     def self.down
  #       save_table_to_fixture("posts")
  #       drop_table "posts"
  #     end
  #   end
  # 
  # When you migrate down (via <tt>rake migrate VERSION=0</tt>), the data for the 
  # +posts+ table is saved in 
  # <tt>db/data/development/posts.yml</tt>, and that data is pushed back 
  # into the table when you migrate back up (via <tt>rake migrate</tt>).
  # 
  # This works great until you have to edit an existing table.  Consider adding a column to the posts
  # table:
  # 
  # <tt>db/migration/002_draft_flag_for_posts.rb:</tt>
  #   class DraftFlagForPosts < ActiveRecord::Migration
  #     def self.up
  #       add_column "posts", "draft", :integer, :limit => 4, :default => 1, :null => false  
  #       Post.reset_column_information
  #       Post.find(:all).each { |p| p.draft == 0 }
  #       restore_table_from_fixture("posts")
  #     end
  # 
  #     def self.down
  #       save_table_to_fixture("posts")
  #       remove_column "posts", "draft"
  #     end
  #   end
  # 
  # With these two migrations, if you run <tt>rake migrate VERSION=0</tt>, the following things will 
  # happen:
  # 
  # 1. <tt>db/data/development/posts.yml</tt> will be created (by migration 002) with the latest version of the table (including the +draft+ column).
  # 2. <tt>db/data/development/posts.yml</tt> will be recreated (by migration 001) with the latest version of the table (including the +draft+ column).  
  # 
  # This is an error, but doesn't cause any real problems just yet.  The problem arrises when you attempt
  # to migrate back up (via <tt>rake migrate</tt>).  The 001 migration attempts to restore the yaml file,
  # but cannot, since the specified +draft+ column doesn't exist in the table.
  # 
  # === +Version+ to the rescue
  # 
  # If we add the +version+ parameter to the calls to +save_table_to_fixture+ 
  # and +restore_table_from_fixture+ in the 002 migration like such:
  # 
  # <tt>db/migration/002_draft_flag_for_posts.rb:</tt>
  #   class DraftFlagForPosts < ActiveRecord::Migration
  #     def self.up
  #       add_column "posts", "draft", :integer, :limit => 4, :default => 1, :null => false  
  #       Post.reset_column_information
  #       Post.find(:all).each { |p| p.draft == 0 }
  #       restore_table_from_fixture("posts", ".draftcol")
  #     end
  # 
  #     def self.down
  #       save_table_to_fixture("posts", ".draftcol")
  #       remove_column "posts", "draft"
  #     end
  #   end
  # 
  # Then the latter fixture is named <tt>db/data/development/posts.draftcol.yml</tt>, avoiding the whole
  # issue.
  # 
  # == Caveats
  # 
  # This is in use in my personal projects, but not highly tested.  It is almost definitely MySQL 
  # and unix dependent, since I'm too lazy to change those things.  Enhancements and bug fixes
  # are welcome.

  class Migration

    private

    # Saves the table data into a fixture file named <tt>#{table}#{version}.yml</tt>,
    # in the <tt>#{RAILS_ROOT}/db/data/#{RAILS_ENV}/</tt>
    #
    # Should be called at the beginning of a migration's +down+ method
    def self.save_table_to_fixture(table, version = "") # :doc:
      raise "RAILS_ENV is empty" unless RAILS_ENV
  
      table    = table.to_s
      filename = "#{table}#{version}"
      path     = "#{RAILS_ROOT}/db/data/#{RAILS_ENV}/"
      Dir.mkdir(path) unless File.directory?(path)

      say_with_time("Saving data from #{table} to #{path}/#{filename}.yml") do
        i = 0
        File.open("#{path}/#{filename}.yml", 'wb') do |file|
          file.write ActiveRecord::Base.connection.select_all("SELECT * FROM #{table}").inject({}) { |hash, record|
            hash["#{table}_#{i += 1}"] = record
            hash
          }.to_yaml
        end
      end
    end

    # Restores the table data from a fixture file named <tt>#{table}#{version}.yml</tt>,
    # in the <tt>#{RAILS_ROOT}/db/data/#{RAILS_ENV}/</tt>
    #
    # Should be called at the end of a migration's +down+ method
    def self.restore_table_from_fixture(table, version = "") # :doc:
      raise "\$RAILS_ENV is empty" unless RAILS_ENV
  
      table    = table.to_s
      filename = "#{table}#{version}"
      path     = "#{RAILS_ROOT}/db/data/#{RAILS_ENV}/"
      FileUtils::mkdir_p(path) unless File.directory?(path)
  
      # Not sure on what to do if the file doesn't exist, 
      # but thinking we should just create an empty version and move on.
      FileUtils::touch("#{path}/#{filename}.yml")
      
      say_with_time("Restoring data from #{path}/#{filename}.yml into #{table}") do
        ActiveRecord::Base.connection.transaction do
    
          # Load the yaml...
          require 'yaml'
          if y = YAML.load_file("#{path}/#{filename}.yml")
    
            # Clear out any old data...
            ActiveRecord::Base.connection.execute("delete from #{table}")
    
            # Shove each record into the table
            y.each do |rec_name, record|
              cols = record.keys.map {|k| "`#{k}`"}.join(',')
              vals = (record.values.map do |v| 
                  v == nil ? "null" : "\'#{ActiveRecord::Base.connection.quote_string(v)}\'"
                end).join(',')
              ActiveRecord::Base.connection.execute("insert into #{table} (#{cols}) values (#{vals})")
            end
          else
            puts "Warning: Could not load data from #{path}/#{filename}.yml"
          end
    
        end
      end
    end
  end
end
