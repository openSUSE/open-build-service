require 'active_record/fixtures'

def local_to_yaml(hash, file)
  return if hash.empty?
  keys = hash.keys.sort
  keys.each_with_index do |k, index| # <-- here's my addition (the 'sort')
    v = hash[k]
    k = "record_#{index}" if k.is_a?(Integer)
    file.write({ k => v }.to_yaml(SortKeys: true, ExplicitTypes: true).gsub(%r{^---\s*}, ''))
  end
end

def force_hash(record)
  ret = {}
  record.each do |key, value|
    key = key.dup.force_encoding('UTF-8')
    if value
      value = value.dup.force_encoding('UTF-8') if value.is_a? String
      ret[key] = value
    end
  end
  ret
end

namespace :db do
  desc 'Create YAML test fixtures from data in test database.'

  task extract_fixtures: :environment do
    raise 'You only want to run this in test environment' unless ENV['RAILS_ENV'] == 'test'
    sql = 'SELECT * FROM %s'
    skip_tables = %w(schema_info sessions schema_migrations)
    ActiveRecord::Base.establish_connection
    User.current = User.find_by_login('Admin')
    tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(/,/) : ActiveRecord::Base.connection.tables - skip_tables
    tables.each do |table_name|
      i = '000'
      begin
        oldhash = YAML.load_file("#{Rails.root}/test/fixtures/#{table_name}.yml")
        oldhash ||= {}
      rescue Errno::ENOENT, TypeError
        oldhash = {}
      rescue => e
        puts e.class
        raise e
      end
      idtokey = {}
      force_hash(oldhash).each do |key, record|
        next unless record.has_key? 'id'
        key = key.dup.force_encoding('UTF-8')
        id = Integer(record['id'])
        idtokey[id] = key
      end

      classname = Event::Base if table_name == 'events'

      classname = HistoryElement::Base if table_name == 'history_elements'

      next if %(architectures_distributions roles_static_permissions).include? table_name

      begin
        classname ||= table_name.classify.constantize
      rescue NameError
        # habtm table
        classname = nil
      end

      # next unless table_name == 'taggings'

      File.open("#{Rails.root}/test/fixtures/#{table_name}.yml", 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        hash = {}
        data.each do |record|
          record = force_hash record
          id = i.succ!
          if classname
            primary = classname.primary_key
          else
            primary = 'id'
          end
          id = Integer(record[primary]) if record.has_key? primary
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
          %w(db_project project develproject maintenance_project).each do |prefix|
            next unless record.has_key?(prefix + '_id')
            p = Project.find(record.delete(prefix + '_id'))
            prefix = 'project' if prefix == 'db_project'
            record[prefix] = p.name.tr(':', '_')
          end
          %w(package develpackage links_to).each do |prefix|
            if record.has_key?(prefix + '_id')
              p = Package.find(record.delete(prefix + '_id'))
              record[prefix] = p.fixtures_name
            end
          end
          if record.has_key?('linked_db_project_id')
            pid = record.delete('linked_db_project_id')
            if pid > 0
              p = Project.find(pid)
              record['linked_db_project'] = p.name.tr(':', '_')
            end
          end
          if table_name == 'taggings'
            if record['taggable_type'] == 'Project'
              record['taggable_id'] = ActiveRecord::FixtureSet.identify(Project.find(record['taggable_id']).name.tr(':', '_'))
            end
            if record['taggable_type'] == 'Package'
              record['taggable_id'] = ActiveRecord::FixtureSet.identify(Package.find(record['taggable_id']).fixtures_name)
            end
          end

          if table_name == 'distributions'
            dist = Distribution.find(id)
            archs = dist.architectures.pluck(:name).join(', ')
            record['architectures'] = archs if archs.present?
          end
          defaultkey = "#{table_name}_#{id}".force_encoding('UTF-8')
          key = idtokey[id]
          key = nil if key == defaultkey

          if table_name == 'roles_users'
            defaultkey = "#{record['user']}_#{record['role']}"
          end
          if table_name == 'roles_static_permissions'
            defaultkey = "#{record['role']}_#{record['static_permission']}"
          end
          if table_name == 'projects' || table_name == 'architectures'
            key = record['name'].tr(':', '_')
            record.delete(primary)
          end
          if %w(static_permissions packages).include? table_name
            key = classname.find(record.delete(primary)).fixtures_name
          end
          defaultkey = record['package'] if table_name == 'backend_packages'
          if %w(event_subscriptions ratings package_kinds package_issues
                linked_db_projects relationships watched_projects path_elements groups_users
                flags taggings bs_request_histories bs_request_actions project_log_entries).include? table_name
            record.delete(primary)
            t = record.to_a.sort
            # a bit clumpsy but reliable order is important for git diff
            key = Digest::MD5.hexdigest(t.to_yaml).to_i(16)
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
          raise "duplicated record #{table_name}:#{key}" if hash.has_key? key
          hash[key] = record
        end
        local_to_yaml(hash, file)
      end
    end
  end
end
