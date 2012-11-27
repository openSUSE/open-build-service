
def local_to_yaml( hash, file )
   hash.sort.each do |k, v|   # <-- here's my addition (the 'sort')
     file.write( {k => v}.to_yaml(:SortKeys => true, :ExplicitTypes => true).gsub(%r{^---\s*}, '') )
   end
end

def force_hash( record )
  ret = Hash.new
  record.each do |key, value|
    key = key.dup.force_encoding("UTF-8")
    if value
      value = value.dup.force_encoding("UTF-8") if value.kind_of? String
      ret[key] = value
    end
  end
  ret
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
      begin
        oldhash = YAML.load_file( "#{Rails.root}/test/fixtures/#{table_name}.yml" )
        oldhash = {} unless oldhash
      rescue Errno::ENOENT, TypeError
	oldhash = {}
      rescue => e
	puts e.class
	raise e
      end
      idtokey = {}
      force_hash(oldhash).each do |key, record| 
        if record.has_key? 'id'
           key = key.dup.force_encoding("UTF-8")
           id = Integer(record['id'])
           idtokey[id] = key
        end
      end
      File.open("#{Rails.root}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        hash = {}
        data.each do |record|
          record = force_hash record
          id=i.succ!
          if record.has_key? 'id'
            id=Integer(record['id'])
          end
          key = idtokey[id] || "#{table_name}_#{id}".force_encoding("UTF-8")
          raise "duplicated record" if hash.has_key? key
          hash[key] = record
        end
        local_to_yaml( hash, file)
      end
    end
  end
end
