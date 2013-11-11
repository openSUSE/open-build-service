require 'active_record/fixtures'

def local_to_yaml(hash, file)
  hash.sort.each do |k, v| # <-- here's my addition (the 'sort')
    file.write({k => v}.to_yaml(:SortKeys => true, :ExplicitTypes => true).gsub(%r{^---\s*}, ''))
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

      next if table_name == 'architectures_distributions'

      begin
        classname = table_name.classify.constantize unless classname
      rescue NameError
        # habtm table
        classname = nil
      end

      next unless table_name == 'taggings'

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
          if record.has_key?('architecture_id')
            arch = Architecture.find(record.delete('architecture_id'))
            record['architecture'] = arch.name
          end
          if record.has_key?('static_permission_id')
            perm = StaticPermission.find(record.delete('static_permission_id'))
            record['static_permission'] = perm.title
          end
          if record.has_key?('project_id')
            p = Project.find(record.delete('project_id'))
            record['project'] = p.name.gsub(':', '_')
          end
          if record.has_key?('db_project_id')
            p = Project.find(record.delete('db_project_id'))
            record['project'] = p.name.gsub(':', '_')
          end
          if record.has_key?('linked_db_project_id')
            pid = record.delete('linked_db_project_id')
            if pid > 0
              p = Project.find(pid)
              record['linked_db_project'] = p.name.gsub(':', '_')
            end
          end
          if table_name == 'taggings'
            if record['taggable_type'] == 'Project'
              record['taggable_id'] = ActiveRecord::FixtureSet.identify(Project.find(record['taggable_id']).name.gsub(':', '_'))
            end
          end

          if table_name == 'distributions'
            dist = Distribution.find(id)
            archs = dist.architectures.pluck(:name).join(', ')
            record['architectures'] = archs if archs.present?
          end
          defaultkey = "#{table_name}_#{id}".force_encoding("UTF-8")
          key = idtokey[id]
          key = nil if key == defaultkey

          if table_name == 'roles_users'
            defaultkey = "#{record['user']}_#{record['role']}"
          end
          if table_name == 'roles_static_permissions'
            defaultkey = "#{record['role']}_#{record['static_permission']}"
          end
          if table_name == 'projects'
            defaultkey = record['name'].gsub(':', '_')
            record.delete(primary)
          end
          if table_name == 'db_project_types'
            defaultkey = record['name']
          end

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
          # puts "#{table_name} #{record.inspect} -#{key}-"
          key ||= defaultkey
          raise "duplicated record" if hash.has_key? key
          hash[key] = record
        end
        local_to_yaml(hash, file)
      end
    end
  end
end
