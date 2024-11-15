require 'active_record/fixtures'

def local_to_yaml(hash, file)
  return if hash.empty?

  keys = hash.keys.sort
  keys.each_with_index do |k, index| # <-- here's my addition (the 'sort')
    v = hash[k]
    k = "record_#{index}" if k.is_a?(Integer)
    file.write({ k => v }.to_yaml(SortKeys: true, ExplicitTypes: true).gsub(/^---\s*/, ''))
  end
end

def force_hash(record)
  ret = {}
  record.each do |key, value|
    key = key.dup.force_encoding('UTF-8')
    if value
      value = value.dup.force_encoding('UTF-8') if value.is_a?(String)
      ret[key] = value
    end
  end
  ret
end

namespace :db do
  desc 'Create YAML test fixtures from data in test database.'

  task extract_fixtures: :environment do
    raise 'You only want to run this in test environment' unless ENV.fetch('RAILS_ENV', nil) == 'test'

    sql = 'SELECT * FROM %s'
    skip_tables = %w[schema_info sessions schema_migrations]
    ActiveRecord::Base.establish_connection
    User.session = User.default_admin
    tables = ENV['FIXTURES'] ? ENV['FIXTURES'].split(',') : ActiveRecord::Base.connection.tables - skip_tables
    tables.each do |table_name|
      i = '000'
      begin
        oldhash = YAML.load_file(Rails.root.join("test/fixtures/#{table_name}.yml").to_s)
        oldhash ||= {}
      rescue Errno::ENOENT, TypeError
        oldhash = {}
      rescue StandardError => e
        puts e.class
        raise e
      end
      idtokey = {}
      force_hash(oldhash).each do |key, record|
        next unless record.key?('id')

        key = key.dup.force_encoding('UTF-8')
        id = Integer(record['id'])
        idtokey[id] = key
      end

      classname = Event::Base if table_name == 'events'

      classname = HistoryElement::Base if table_name == 'history_elements'

      next if %(architectures_distributions roles_static_permissions).include?(table_name)

      begin
        classname ||= table_name.classify.constantize
      rescue NameError
        # habtm table
        classname = nil
      end

      # next unless table_name == 'taggings'

      File.open(Rails.root.join("test/fixtures/#{table_name}.yml").to_s, 'w') do |file|
        data = ActiveRecord::Base.connection.select_all(sql % table_name)
        hash = {}

        project_prefixes = %w[db_project project develproject maintenance_project]
        package_prefixes = %w[package develpackage links_to]
        projects_or_architectures = %w[projects architectures]
        various_table_names = %w[event_subscriptions package_kinds package_issues
                                 linked_db_projects relationships watched_items path_elements
                                 groups_users flags taggings bs_request_histories
                                 bs_request_actions project_log_entries]
        static_permissions_or_packages = %w[static_permissions packages]

        data.each do |record|
          record = force_hash(record)
          id = i.succ!
          primary = if classname
                      classname.primary_key
                    else
                      'id'
                    end
          id = Integer(record[primary]) if record.key?(primary)
          if record.key?('user_id')
            user = User.find(record.delete('user_id'))
            record['user'] = user.login
          end
          if record.key?('owner_id')
            user = User.find(record.delete('owner_id'))
            record['owner'] = user.login
          end
          if record.key?('role_id')
            role = Role.find(record.delete('role_id'))
            record['role'] = role.title
          end
          if record.key?('group_id')
            group = Group.find(record.delete('group_id'))
            record['group'] = group.title
          end
          if record.key?('architecture_id')
            arch = Architecture.find(record.delete('architecture_id'))
            record['architecture'] = arch.name
          end
          if record.key?('static_permission_id')
            perm = StaticPermission.find(record.delete('static_permission_id'))
            record['static_permission'] = perm.title
          end
          project_prefixes.each do |prefix|
            next unless record.key?("#{prefix}_id")

            p = Project.find(record.delete("#{prefix}_id"))
            prefix = 'project' if prefix == 'db_project'
            record[prefix] = p.name.tr(':', '_')
          end
          package_prefixes.each do |prefix|
            if record.key?("#{prefix}_id")
              p = Package.find(record.delete("#{prefix}_id"))
              record[prefix] = p.fixtures_name
            end
          end
          if record.key?('linked_db_project_id')
            pid = record.delete('linked_db_project_id')
            if pid.positive?
              p = Project.find(pid)
              record['linked_db_project'] = p.name.tr(':', '_')
            end
          end
          if table_name == 'taggings'
            record['taggable_id'] = ActiveRecord::FixtureSet.identify(Project.find(record['taggable_id']).name.tr(':', '_')) if record['taggable_type'] == 'Project'
            record['taggable_id'] = ActiveRecord::FixtureSet.identify(Package.find(record['taggable_id']).fixtures_name) if record['taggable_type'] == 'Package'
          end

          if table_name == 'distributions'
            dist = Distribution.find(id)
            archs = dist.architectures.pluck(:name).join(', ')
            record['architectures'] = archs if archs.present?
          end
          defaultkey = "#{table_name}_#{id}".force_encoding('UTF-8')
          key = idtokey[id]
          key = nil if key == defaultkey

          defaultkey = "#{record['user']}_#{record['role']}" if table_name == 'roles_users'
          defaultkey = "#{record['role']}_#{record['static_permission']}" if table_name == 'roles_static_permissions'
          if projects_or_architectures.include?(table_name)
            key = record['name'].tr(':', '_')
            record.delete(primary)
          end
          key = classname.find(record.delete(primary)).fixtures_name if static_permissions_or_packages.include?(table_name)
          defaultkey = record['package'] if table_name == 'backend_packages'
          if various_table_names.include?(table_name)

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
          raise "duplicated record #{table_name}:#{key}" if hash.key?(key)

          hash[key] = record
        end
        local_to_yaml(hash, file)
      end
    end
  end
end
