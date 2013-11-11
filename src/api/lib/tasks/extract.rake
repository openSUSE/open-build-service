def local_to_yaml(hash, file)
  hash.sort.each do |k, v| # <-- here's my addition (the 'sort')
    file.write({ k => v }.to_yaml(:SortKeys => true, :ExplicitTypes => true).gsub(%r{^---\s*}, ''))
  end
end

def force_hash(record)
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
    User.current = User.find_by_login('Admin')
    tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : ActiveRecord::Base.connection.tables - skip_tables
    tables.each do |table_name|
      i = "000"
      begin
        oldhash = YAML.load_file("#{Rails.root}/test/fixtures/#{table_name}.yml")
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

      if table_name == 'events'
        classname = Event::Base
      end

      begin
        classname = table_name.classify.constantize unless classname
      rescue NameError
        # habtm table
        classname = nil
      end

      File.open("#{Rails.root}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        hash = {}
        data.each do |record|
          record = force_hash record
          id=i.succ!
          if classname
            primary = classname.primary_key
          else
            primary = 'id'
          end
          if record.has_key? primary
            id=Integer(record[primary])
          end
          if record.has_key?('user_id')
            user = User.find(record.delete('user_id'))
            record['user'] = user.login
          end
          if record.has_key?('owner_id')
            user = User.find(record.delete('owner_id'))
            record['owner'] = user.login
          end
          if record.has_key?('role_id')
            role = Role.find(record.delete('role_id'))
            record['role'] = role.title
          end
          if record.has_key?('group_id')
            group = Group.find(record.delete('group_id'))
            record['group'] = group.title
          end
          key = idtokey[id]
          if key.blank? && classname
            begin
              key = classname.find(id).to_param
              begin
                Integer(key)
                key = nil # if it's a valid integer, ignore it :)
              rescue Exception
	      	record.delete(primary)
              end
            rescue ActiveRecord::StatementInvalid
              # models without primary key
            end
          end
          #puts "#{table_name} #{record.inspect} -#{key}-"
          key ||= "#{table_name}_#{id}".force_encoding("UTF-8")
          raise "duplicated record" if hash.has_key? key
          hash[key] = record
        end
        local_to_yaml(hash, file)
      end
    end
  end
end
