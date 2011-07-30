def local_to_yaml( hash, file )
   hash.sort.each do |k, v|   # <-- here's my addition (the 'sort')
     file.write( {k => v}.to_yaml.gsub(%r{^---\s*}, '') )
   end
end

namespace :db do
  desc 'Create YAML test fixtures from data in test database.'

  task :extract_fixtures => :environment do
    raise "You only want to run this in test environment" unless ENV['RAILS_ENV'] == 'test'
    sql = "SELECT * FROM %s"
    skip_tables = ["schema_info", "sessions", "schema_migrations"]
    ActiveRecord::Base.establish_connection
    tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : ActiveRecord::Base.connection.tables - skip_tables
    tables.each do |table_name|
      i = "000"
      File.open("#{RAILS_ROOT}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        hash = {}
        data.each do |record|
          id=i.succ!
          if record.has_key? 'id'
            id=record['id']
          end
          raise "duplicated record" if hash.has_key? "#{table_name}_#{id}"
          hash["#{table_name}_#{id}"] = record
        end
        local_to_yaml( hash, file)
      end
    end
  end
end
