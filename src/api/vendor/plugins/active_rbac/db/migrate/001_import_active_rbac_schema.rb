class ImportActiveRbacSchema < ActiveRecord::Migration
  def self.up
    # read the SQL script
    adapter = ActiveRecord::Base.configurations['development']['adapter']

    schema_dir = Pathname.new(__FILE__).dirname.realpath.parent.to_s
    filename = File.join(schema_dir, "create.#{adapter}.sql")
    
    raise "Could not find schema file #{filename}" unless File.exists?(filename)
    
    fcontent = IO.read(filename)
    
    # execute the SQL
    puts "Executing SQL script #{filename}"
    # execute SQL statements one by one since execute breaks with MySQL otherwise
    fcontent.split(';').each do |statement|
      execute statement
    end
    puts "Complete"
  end

  def self.down
    # Search all CREATE_TABLE statements and DROP all tables.
    adapter = ActiveRecord::Base.configurations['development']['adapter']

    schema_dir = Pathname.new(__FILE__).dirname.realpath.parent.to_s
    filename = File.join(schema_dir, "create.#{adapter}.sql")
    
    raise "Could not find schema file #{filename}" unless File.exists?(filename)
    
    fcontent = IO.read(filename)
    
    tables = fcontent.scan %r{CREATE TABLE (\S*)}
    
    tables.reverse_each do |table_name|
      drop_table table_name
    end
  end
end