class InitialDatabase < ActiveRecord::Migration[4.2]
  # rubocop:disable Metrics/AbcSize
  # rubocop:disable MethodLength
  # rubocop:disable Metrics/LineLength
  def self.up
    # rubocop:disable Layout/ExtraSpacing
    create_table 'architectures', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string  'name',                      null: false, collation: 'utf8_general_ci'
      t.boolean 'available', default: false
      t.index ['name'], name: 'arch_name_index', unique: true, using: :btree
    end

    create_table 'architectures_distributions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'distribution_id'
      t.integer 'architecture_id'
    end

    create_table 'attrib_allowed_values', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id',               null: false
      t.text    'value',          limit: 65_535,              collation: 'utf8_general_ci'
      t.index ['attrib_type_id'], name: 'attrib_type_id', using: :btree
    end

    create_table 'attrib_default_values', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id',               null: false
      t.text    'value',          limit: 65_535, null: false, collation: 'utf8_general_ci'
      t.integer 'position',                     null: false
      t.index ['attrib_type_id'], name: 'attrib_type_id', using: :btree
    end

    create_table 'attrib_issues', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'attrib_id', null: false
      t.integer 'issue_id',  null: false
      t.index ['attrib_id', 'issue_id'], name: 'index_attrib_issues_on_attrib_id_and_issue_id', unique: true, using: :btree
      t.index ['issue_id'], name: 'issue_id', using: :btree
    end

    create_table 'attrib_namespace_modifiable_bies', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'attrib_namespace_id', null: false
      t.integer 'user_id'
      t.integer 'group_id'
      t.index ['attrib_namespace_id', 'user_id', 'group_id'], name: 'attrib_namespace_user_role_all_index', unique: true, using: :btree
      t.index ['attrib_namespace_id'], name: 'index_attrib_namespace_modifiable_bies_on_attrib_namespace_id', using: :btree
      t.index ['user_id'], name: 'bs_user_id', using: :btree
      t.index ['group_id'], name: 'bs_group_id', using: :btree
    end

    create_table 'attrib_namespaces', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', collation: 'utf8_general_ci'
      t.index ['name'], name: 'index_attrib_namespaces_on_name', using: :btree
    end

    create_table 'attrib_type_modifiable_bies', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'attrib_type_id', null: false
      t.integer 'user_id'
      t.integer 'group_id', options: 'AFTER user_id'
      t.integer 'role_id'
      t.index ['attrib_type_id', 'user_id', 'group_id', 'role_id'], name: 'attrib_type_user_role_all_index', unique: true, using: :btree
      t.index ['user_id'], name: 'user_id', using: :btree
      t.index ['group_id'], name: 'group_id', using: :btree
      t.index ['role_id'], name: 'role_id', using: :btree
    end

    create_table 'attrib_types', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string  'name',                                null: false, collation: 'utf8_general_ci'
      t.string  'description',                                      collation: 'utf8_general_ci'
      t.string  'type',                                             collation: 'utf8_general_ci'
      t.integer 'value_count'
      t.integer 'attrib_namespace_id',                 null: false
      t.boolean 'issue_list',          default: false
      t.index ['attrib_namespace_id', 'name'], name: 'index_attrib_types_on_attrib_namespace_id_and_name', unique: true, using: :btree
      t.index ['attrib_namespace_id'], name: 'attrib_namespace_id', using: :btree
      t.index ['name'], name: 'index_attrib_types_on_name', using: :btree
    end

    create_table 'attrib_values', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_id',               null: false
      t.text    'value',     limit: 65_535, null: false, collation: 'utf8_general_ci'
      t.integer 'position',                null: false
      t.index ['attrib_id', 'position'], name: 'index_attrib_values_on_attrib_id_and_position', unique: true, using: :btree
      t.index ['attrib_id'], name: 'index_attrib_values_on_attrib_id', using: :btree
    end

    create_table 'attribs', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id', null: false
      t.integer 'package_id'
      t.string  'binary',                      collation: 'utf8_general_ci'
      t.integer 'project_id'
      t.index ['attrib_type_id', 'package_id', 'project_id', 'binary'], name: 'attribs_index', unique: true, using: :btree
      t.index ['attrib_type_id', 'project_id', 'package_id', 'binary'], name: 'attribs_on_proj_and_pack', unique: true, using: :btree
      t.index ['package_id'], name: 'index_attribs_on_package_id', using: :btree
      t.index ['project_id'], name: 'index_attribs_on_project_id', using: :btree
    end

    create_table 'backend_infos', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string   'key',        null: false
      t.string   'value',      null: false
      t.datetime 'created_at'
      t.datetime 'updated_at'
    end

    create_table 'backend_packages', primary_key: 'package_id', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer  'links_to_id'
      t.datetime 'updated_at'
      t.string   'srcmd5'
      t.string   'changesmd5'
      t.string   'verifymd5'
      t.string   'expandedmd5'
      t.text     'error',       limit: 65_535
      t.datetime 'maxmtime'
      t.index ['links_to_id'], name: 'index_backend_packages_on_links_to_id', using: :btree
    end

    create_table 'blacklist_tags', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name',       collation: 'utf8_general_ci'
      t.datetime 'created_at'
    end

    create_table 'bs_request_action_accept_infos', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer  'bs_request_action_id'
      t.string   'rev'
      t.string   'srcmd5'
      t.string   'xsrcmd5'
      t.string   'osrcmd5'
      t.string   'oxsrcmd5'
      t.datetime 'created_at'
      t.index ['bs_request_action_id'], name: 'bs_request_action_id', using: :btree
    end

    create_table 'bs_request_actions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'bs_request_id'
      t.string   'type'
      t.string   'target_project',                        collation: 'utf8_unicode_ci'
      t.string   'target_package',                        collation: 'utf8_unicode_ci'
      t.string   'target_releaseproject',                 collation: 'utf8_unicode_ci'
      t.string   'source_project',                        collation: 'utf8_unicode_ci'
      t.string   'source_package',                        collation: 'utf8_unicode_ci'
      t.string   'source_rev',                            collation: 'utf8_unicode_ci'
      t.string   'sourceupdate',                          collation: 'utf8_unicode_ci'
      t.boolean  'updatelink',            default: false
      t.string   'person_name',                           collation: 'utf8_unicode_ci'
      t.string   'group_name',                            collation: 'utf8_unicode_ci'
      t.string   'role',                                  collation: 'utf8_unicode_ci'
      t.datetime 'created_at'
      t.string   'target_repository'
      t.index ['bs_request_id'], name: 'bs_request_id', using: :btree
      t.index ['target_project'], name: 'index_bs_request_actions_on_target_project', using: :btree
      t.index ['target_package'], name: 'index_bs_request_actions_on_target_package', using: :btree
      t.index ['source_project'], name: 'index_bs_request_actions_on_source_project', using: :btree
      t.index ['source_package'], name: 'index_bs_request_actions_on_source_package', using: :btree
      t.index ['target_project', 'source_project'], name: 'index_bs_request_actions_on_target_project_and_source_project', using: :btree
    end

    create_table 'bs_request_histories', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'bs_request_id'
      t.string   'state',                       collation: 'utf8_unicode_ci'
      t.text     'comment',       limit: 65_535
      t.string   'commenter',                   collation: 'utf8_unicode_ci'
      t.integer  'superseded_by'
      t.datetime 'created_at'
      t.index ['bs_request_id'], name: 'bs_request_id', using: :btree
    end

    create_table 'bs_requests', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.text     'description',   limit: 65_535
      t.string   'creator',                                  collation: 'utf8_unicode_ci'
      t.string   'state',                                    collation: 'utf8_unicode_ci'
      t.text     'comment',       limit: 65_535
      t.string   'commenter',                                collation: 'utf8_unicode_ci'
      t.integer  'superseded_by'
      t.datetime 'created_at',                  null: false
      t.datetime 'updated_at',                  null: false
      t.datetime 'accept_at'
      t.index ['creator'], name: 'index_bs_requests_on_creator', using: :btree
      t.index ['state'], name: 'index_bs_requests_on_state', using: :btree
    end

    create_table 'cache_lines', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string   'key',        null: false
      t.string   'package'
      t.string   'project'
      t.integer  'request'
      t.datetime 'created_at'
      t.index ['project', 'package'], name: 'index_cache_lines_on_project_and_package', using: :btree
      t.index ['project'], name: 'index_cache_lines_on_project', using: :btree
    end

    create_table 'channel_binaries', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string  'name',                   null: false
      t.integer 'channel_binary_list_id', null: false
      t.integer 'project_id'
      t.integer 'repository_id'
      t.integer 'architecture_id'
      t.string  'package'
      t.string  'binaryarch'
      t.string  'supportstatus'
      t.index ['project_id', 'package'], name: 'index_channel_binaries_on_project_id_and_package', using: :btree
      t.index ['channel_binary_list_id'], name: 'channel_binary_list_id', using: :btree
      t.index ['repository_id'], name: 'repository_id', using: :btree
      t.index ['architecture_id'], name: 'architecture_id', using: :btree
      t.index ['name', 'channel_binary_list_id'], name: 'index_channel_binaries_on_name_and_channel_binary_list_id', using: :btree
    end

    create_table 'channel_binary_lists', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'channel_id',      null: false
      t.integer 'project_id'
      t.integer 'repository_id'
      t.integer 'architecture_id'
      t.index ['channel_id'], name: 'channel_id', using: :btree
      t.index ['project_id'], name: 'project_id', using: :btree
      t.index ['repository_id'], name: 'repository_id', using: :btree
      t.index ['architecture_id'], name: 'architecture_id', using: :btree
    end

    create_table 'channel_targets', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'channel_id',    null: false
      t.integer 'repository_id', null: false
      t.string  'prefix'
      t.string  'tag'
      t.index ['channel_id', 'repository_id'], name: 'index_channel_targets_on_channel_id_and_repository_id', unique: true, using: :btree
      t.index ['repository_id'], name: 'repository_id', using: :btree
    end

    create_table 'channels', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'package_id', null: false
      t.index ['package_id'], name: 'package_id', using: :btree
    end

    create_table 'comments', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer  'project_id'
      t.integer  'package_id'
      t.integer  'bs_request_id'
      t.text     'body',          limit: 65_535
      t.integer  'parent_id'
      t.string   'type'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.integer  'user_id',                     null: false
      t.index ['user_id'], name: 'user_id', using: :btree
      t.index ['bs_request_id'], name: 'index_comments_on_bs_request_id', using: :btree
      t.index ['package_id'], name: 'index_comments_on_package_id', using: :btree
      t.index ['parent_id'], name: 'parent_id', using: :btree
      t.index ['project_id'], name: 'index_comments_on_project_id', using: :btree
    end

    create_table 'configurations', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'title',                                           default: ''
      t.text     'description',                       limit: 65_535,                                               collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string   'name',                                            default: ''
      t.string   'registration',                      limit: 12,    default: 'allow'
      t.boolean  'anonymous',                                       default: true
      t.boolean  'default_access_disabled',                         default: false
      t.boolean  'allow_user_to_create_home_project',               default: true
      t.boolean  'disallow_group_creation',                         default: false
      t.boolean  'change_password',                                 default: true
      t.boolean  'hide_private_options',                            default: false
      t.boolean  'gravatar',                                        default: true
      t.boolean  'enforce_project_keys',                            default: true
      t.boolean  'download_on_demand',                              default: true
      t.string   'download_url'
      t.string   'ymp_url'
      t.string   'bugzilla_url'
      t.string   'http_proxy'
      t.string   'no_proxy'
      t.string   'theme'
      t.string   'obs_url'
      t.integer  'cleanup_after_days'
      t.string   'admin_email',                                     default: 'unconfigured@openbuildservice.org'
    end

    create_table 'db_project_types', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
    end

    create_table 'db_projects_tags', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'db_project_id', null: false
      t.integer 'tag_id',        null: false
      t.index ['db_project_id', 'tag_id'], name: 'projects_tags_all_index', unique: true, using: :btree
      t.index ['tag_id'], name: 'tag_id', using: :btree
    end

    create_table 'delayed_jobs', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'priority',                 default: 0
      t.integer  'attempts',                 default: 0
      t.text     'handler',    limit: 65_535,             collation: 'utf8_general_ci'
      t.text     'last_error', limit: 65_535,             collation: 'utf8_general_ci'
      t.datetime 'run_at'
      t.datetime 'locked_at'
      t.datetime 'failed_at'
      t.string   'locked_by',                            collation: 'utf8_general_ci'
      t.string   'queue',                                collation: 'utf8_general_ci'
    end

    create_table 'distribution_icons', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string  'url',    null: false
      t.integer 'width'
      t.integer 'height'
    end

    create_table 'distribution_icons_distributions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'distribution_id'
      t.integer 'distribution_icon_id'
    end

    create_table 'distributions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'vendor',     null: false
      t.string 'version',    null: false
      t.string 'name',       null: false
      t.string 'project',    null: false
      t.string 'reponame',   null: false
      t.string 'repository', null: false
      t.string 'link'
    end

    create_table 'downloads', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string  'baseurl',         collation: 'utf8_general_ci'
      t.string  'metafile',        collation: 'utf8_general_ci'
      t.string  'mtype',           collation: 'utf8_general_ci'
      t.integer 'architecture_id'
      t.integer 'db_project_id'
      t.index ['architecture_id'], name: 'index_downloads_on_architecture_id', using: :btree
      t.index ['db_project_id'], name: 'index_downloads_on_db_project_id', using: :btree
    end

    create_table 'event_subscriptions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string   'eventtype',                    null: false
      t.string   'receiver_role',                null: false
      t.integer  'user_id'
      t.integer  'project_id'
      t.integer  'package_id'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.boolean  'receive',       default: true, null: false
      t.index ['package_id'], name: 'index_event_subscriptions_on_package_id', using: :btree
      t.index ['project_id'], name: 'index_event_subscriptions_on_project_id', using: :btree
      t.index ['user_id'], name: 'index_event_subscriptions_on_user_id', using: :btree
    end

    create_table 'events', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string   'eventtype',                                    null: false
      t.text     'payload',        limit: 65_535
      t.boolean  'queued',                       default: false, null: false
      t.integer  'lock_version',                 default: 0,     null: false
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.boolean  'project_logged',               default: false
      t.index ['queued'], name: 'index_events_on_queued', using: :btree
      t.index ['project_logged'], name: 'index_events_on_project_logged', using: :btree
      t.index ['eventtype'], name: 'index_events_on_eventtype', using: :btree
      t.index ['created_at'], name: 'index_events_on_created_at', using: :btree
    end

    create_table 'flags', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.column  'status', "enum('enable','disable')", limit: 7,  null: false, collation: 'utf8_general_ci'
      t.string  'repo',                                    collation: 'utf8_general_ci'
      t.integer 'project_id'
      t.integer 'package_id'
      t.integer 'architecture_id'
      t.integer 'position',                   null: false
      t.column  'flag', "enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock')", limit: 14, null: false, collation: 'utf8_general_ci'
      t.index ['flag'], name: 'index_flags_on_flag', using: :btree
      t.index ['architecture_id'], name: 'architecture_id', using: :btree
      t.index ['package_id'], name: 'index_flags_on_package_id', using: :btree
      t.index ['project_id'], name: 'index_flags_on_project_id', using: :btree
    end

    create_table 'group_request_requests', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'bs_request_action_group_id'
      t.integer 'bs_request_id'
      t.index ['bs_request_id'], name: 'index_group_request_requests_on_bs_request_id', using: :btree
      t.index ['bs_request_action_group_id'], name: 'index_group_request_requests_on_bs_request_action_group_id', using: :btree
    end

    create_table 'groups', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string   'title',      limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.integer  'parent_id'
      t.string   'email'
      t.index ['parent_id'], name: 'groups_parent_id_index', using: :btree
      t.index ['title'], name: 'index_groups_on_title', using: :btree
    end

    create_table 'groups_roles', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer  'group_id',   default: 0, null: false
      t.integer  'role_id',    default: 0, null: false
      t.datetime 'created_at'
      t.index ['group_id', 'role_id'], name: 'groups_roles_all_index', unique: true, using: :btree
      t.index ['role_id'], name: 'role_id', using: :btree
    end

    create_table 'groups_users', options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer  'group_id',   default: 0,    null: false
      t.integer  'user_id',    default: 0,    null: false
      t.datetime 'created_at'
      t.boolean  'email',      default: true
      t.index ['group_id', 'user_id'], name: 'groups_users_all_index', unique: true, using: :btree
      t.index ['user_id'], name: 'user_id', using: :btree
    end

    create_table 'incident_counter', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'maintenance_db_project_id'
      t.integer 'counter',                   default: 0
    end

    create_table 'issue_trackers', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name',                                         null: false, collation: 'utf8_general_ci'
      t.string   'kind',           limit: 11,                                 collation: 'utf8_general_ci'
      t.string   'description',                                               collation: 'utf8_general_ci'
      t.string   'url',                                          null: false, collation: 'utf8_general_ci'
      t.string   'show_url',                                                  collation: 'utf8_general_ci'
      t.string   'regex',                                        null: false, collation: 'utf8_general_ci'
      t.string   'user',                                                      collation: 'utf8_general_ci'
      t.string   'password',                                                  collation: 'utf8_general_ci'
      t.text     'label',          limit: 65_535,                 null: false, collation: 'utf8_general_ci'
      t.datetime 'issues_updated',                               null: false
      t.boolean  'enable_fetch',                 default: false
    end

    create_table 'issues', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name',                       null: false, collation: 'utf8_general_ci'
      t.integer  'issue_tracker_id',           null: false
      t.string   'summary',                                 collation: 'utf8_general_ci'
      t.integer  'owner_id'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.column   'state', "enum('OPEN','CLOSED','UNKNOWN')", limit: 7,              collation: 'utf8_general_ci'
      t.index ['owner_id'], name: 'owner_id', using: :btree
      t.index ['issue_tracker_id'], name: 'issue_tracker_id', using: :btree
      t.index ['name', 'issue_tracker_id'], name: 'index_issues_on_name_and_issue_tracker_id', using: :btree
    end

    create_table 'linked_projects', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id',              null: false
      t.integer 'linked_db_project_id'
      t.integer 'position'
      t.string  'linked_remote_project_name',              collation: 'utf8_general_ci'
      t.index ['db_project_id', 'linked_db_project_id'], name: 'linked_projects_index', unique: true, using: :btree
    end

    create_table 'maintenance_incidents', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id'
      t.integer 'maintenance_db_project_id'
      t.integer 'request'
      t.string  'updateinfo_id',             collation: 'utf8_general_ci'
      t.integer 'incident_id'
      t.index ['db_project_id'], name: 'index_maintenance_incidents_on_db_project_id', using: :btree
      t.index ['maintenance_db_project_id'], name: 'index_maintenance_incidents_on_maintenance_db_project_id', using: :btree
    end

    create_table 'messages', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'db_object_id'
      t.string   'db_object_type',               collation: 'utf8_general_ci'
      t.integer  'user_id'
      t.datetime 'created_at'
      t.boolean  'send_mail'
      t.datetime 'sent_at'
      t.boolean  'private'
      t.integer  'severity'
      t.text     'text',           limit: 65_535, collation: 'utf8_general_ci'
      t.index ['db_object_id'], name: 'object', using: :btree
      t.index ['user_id'], name: 'user', using: :btree
    end

    create_table 'package_issues', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'package_id',           null: false
      t.integer 'issue_id',             null: false
      t.column  'change', "enum('added','deleted','changed','kept')", limit: 7
      t.index ['package_id', 'issue_id'], name: 'index_package_issues_on_package_id_and_issue_id', using: :btree
      t.index ['issue_id'], name: 'index_package_issues_on_issue_id', using: :btree
      t.index ['package_id'], name: 'index_package_issues_on_package_id', using: :btree
    end

    create_table 'package_kinds', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'package_id'
      t.column  'kind', "enum('patchinfo','aggregate','link','channel','product')", limit: 9, null: false
      t.index ['package_id'], name: 'index_package_kinds_on_package_id', using: :btree
    end

    create_table 'packages', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'project_id',                                    null: false
      t.text     'name',            limit: 65_535
      t.string   'title',                                                      collation: 'utf8_general_ci'
      t.text     'description',     limit: 65_535,                              collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string   'url',                                                        collation: 'utf8_general_ci'
      t.integer  'update_counter',                default: 0
      t.float    'activity_index',  limit: 24,    default: 100.0
      t.string   'bcntsynctag',                                                collation: 'utf8_general_ci'
      t.integer  'develpackage_id'
      t.boolean  'delta',                         default: true,  null: false
      t.index ['develpackage_id'], name: 'devel_package_id_index', using: :btree
      t.index ['project_id', 'name'], name: 'packages_all_index', unique: true, length: { name: 255 }, using: :btree
      t.index ['project_id'], name: 'index_packages_on_project_id', using: :btree
      t.index ['updated_at'], name: 'updated_at_index', using: :btree
    end

    create_table 'path_elements', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'parent_id',     null: false
      t.integer 'repository_id', null: false
      t.integer 'position',      null: false
      t.index ['parent_id', 'position'], name: 'parent_repo_pos_index', unique: true, using: :btree
      t.index ['parent_id', 'repository_id'], name: 'parent_repository_index', unique: true, using: :btree
      t.index ['repository_id'], name: 'repository_id', using: :btree
    end

    create_table 'product_channels', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'product_id', null: false
      t.integer 'channel_id', null: false
      t.index ['channel_id', 'product_id'], name: 'index_product_channels_on_channel_id_and_product_id', unique: true, using: :btree
      t.index ['product_id'], name: 'product_id', using: :btree
    end

    create_table 'product_update_repositories', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'product_id'
      t.integer 'repository_id'
      t.index ['product_id'], name: 'product_id', using: :btree
      t.index ['repository_id'], name: 'repository_id', using: :btree
    end

    create_table 'products', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string  'name',       null: false
      t.integer 'package_id', null: false
      t.string  'cpe'
      t.index ['name', 'package_id'], name: 'index_products_on_name_and_package_id', unique: true, using: :btree
      t.index ['package_id'], name: 'package_id', using: :btree
    end

    create_table 'project_log_entries', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer  'project_id'
      t.string   'user_name'
      t.string   'package_name'
      t.integer  'bs_request_id'
      t.datetime 'datetime'
      t.string   'event_type'
      t.text     'additional_info', limit: 65_535
      t.index ['project_id'], name: 'project_id', using: :btree
      t.index ['user_name'], name: 'index_project_log_entries_on_user_name', using: :btree
      t.index ['package_name'], name: 'index_project_log_entries_on_package_name', using: :btree
      t.index ['bs_request_id'], name: 'index_project_log_entries_on_bs_request_id', using: :btree
      t.index ['event_type'], name: 'index_project_log_entries_on_event_type', using: :btree
      t.index ['datetime'], name: 'index_project_log_entries_on_datetime', using: :btree
    end

    create_table 'projects', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.text     'name',                   limit: 65_535
      t.string   'title',                                                            collation: 'utf8_general_ci'
      t.text     'description',            limit: 65_535,                             collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string   'remoteurl',                                                        collation: 'utf8_general_ci'
      t.string   'remoteproject',                                                    collation: 'utf8_general_ci'
      t.integer  'type_id',                                             null: false
      t.integer  'maintenance_project_id'
      t.integer  'develproject_id'
      t.boolean  'delta',                                default: true, null: false
      t.index ['name'], name: 'projects_name_index', unique: true, length: { name: 255 }, using: :btree
      t.index ['updated_at'], name: 'updated_at_index', using: :btree
      t.index ['develproject_id'], name: 'devel_project_id_index', using: :btree
      t.index ['maintenance_project_id'], name: 'index_db_projects_on_maintenance_project_id', using: :btree
      t.index ['type_id'], name: 'type_id', using: :btree
    end

    create_table 'ratings', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'score'
      t.integer  'db_object_id'
      t.string   'db_object_type', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.integer  'user_id'
      t.index ['db_object_id'], name: 'object', using: :btree
      t.index ['user_id'], name: 'user', using: :btree
    end

    create_table 'relationships', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'package_id'
      t.integer 'project_id'
      t.integer 'role_id',    null: false
      t.integer 'user_id'
      t.integer 'group_id'
      t.index ['project_id', 'role_id', 'group_id'], name: 'index_relationships_on_project_id_and_role_id_and_group_id', unique: true, using: :btree
      t.index ['project_id', 'role_id', 'user_id'], name: 'index_relationships_on_project_id_and_role_id_and_user_id', unique: true, using: :btree
      t.index ['package_id', 'role_id', 'group_id'], name: 'index_relationships_on_package_id_and_role_id_and_group_id', unique: true, using: :btree
      t.index ['package_id', 'role_id', 'user_id'], name: 'index_relationships_on_package_id_and_role_id_and_user_id', unique: true, using: :btree
      t.index ['role_id'], name: 'role_id', using: :btree
      t.index ['user_id'], name: 'user_id', using: :btree
      t.index ['group_id'], name: 'group_id', using: :btree
    end

    create_table 'release_targets', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'repository_id',                   null: false
      t.integer 'target_repository_id',            null: false
      t.column  'trigger', "enum('manual','allsucceeded','maintenance')", limit: 12
      t.index ['repository_id'], name: 'repository_id_index', using: :btree
      t.index ['target_repository_id'], name: 'index_release_targets_on_target_repository_id', using: :btree
    end

    create_table 'repositories', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id',                  null: false
      t.string  'name',                           null: false
      t.string  'remote_project_name',                         collation: 'utf8_general_ci'
      t.column  'rebuild', "enum('transitive','direct','local')", limit: 10,              collation: 'utf8_general_ci'
      t.column  'block', "enum('all','local','never')", limit: 5,               collation: 'utf8_general_ci'
      t.column  'linkedbuild', "enum('off','localdep','all')", limit: 8,               collation: 'utf8_general_ci'
      t.integer 'hostsystem_id'
      t.index ['db_project_id', 'name', 'remote_project_name'], name: 'projects_name_index', unique: true, using: :btree
      t.index ['remote_project_name'], name: 'remote_project_name_index', using: :btree
      t.index ['hostsystem_id'], name: 'hostsystem_id', using: :btree
    end

    create_table 'repository_architectures', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'repository_id',               null: false
      t.integer 'architecture_id',             null: false
      t.integer 'position',        default: 0, null: false
      t.index ['architecture_id'], name: 'architecture_id', using: :btree
      t.index ['repository_id', 'architecture_id'], name: 'arch_repo_index', unique: true, using: :btree
    end

    create_table 'reviews', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer  'bs_request_id'
      t.string   'creator'
      t.string   'reviewer'
      t.text     'reason',        limit: 65_535
      t.string   'state'
      t.string   'by_user'
      t.string   'by_group'
      t.string   'by_project'
      t.string   'by_package'
      t.datetime 'created_at',                  null: false
      t.datetime 'updated_at',                  null: false
      t.index ['creator'], name: 'index_reviews_on_creator', using: :btree
      t.index ['reviewer'], name: 'index_reviews_on_reviewer', using: :btree
      t.index ['by_user'], name: 'index_reviews_on_by_user', using: :btree
      t.index ['by_group'], name: 'index_reviews_on_by_group', using: :btree
      t.index ['by_project'], name: 'index_reviews_on_by_project', using: :btree
      t.index ['by_package', 'by_project'], name: 'index_reviews_on_by_package_and_by_project', using: :btree
      t.index ['bs_request_id'], name: 'bs_request_id', using: :btree
      t.index ['state', 'by_project'], name: 'index_reviews_on_state_and_by_project', using: :btree
      t.index ['state', 'by_user'], name: 'index_reviews_on_state_and_by_user', using: :btree
      t.index ['state'], name: 'index_reviews_on_state', using: :btree
    end

    create_table 'roles', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string  'title',     limit: 100, default: '',    null: false, collation: 'utf8_general_ci'
      t.integer 'parent_id'
      t.boolean 'global',                default: false
      t.index ['parent_id'], name: 'roles_parent_id_index', using: :btree
    end

    create_table 'roles_static_permissions', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'role_id',              default: 0, null: false
      t.integer 'static_permission_id', default: 0, null: false
      t.index ['role_id'], name: 'role_id', using: :btree
      t.index ['static_permission_id', 'role_id'], name: 'roles_static_permissions_all_index', unique: true, using: :btree
    end

    create_table 'roles_users', id: false, force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer  'user_id',    default: 0, null: false
      t.integer  'role_id',    default: 0, null: false
      t.datetime 'created_at'
      t.index ['role_id'], name: 'role_id', using: :btree
      t.index ['user_id', 'role_id'], name: 'roles_users_all_index', unique: true, using: :btree
    end

    create_table 'sessions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string   'session_id',               null: false
      t.text     'data',       limit: 65_535
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.index ['session_id'], name: 'index_sessions_on_session_id', using: :btree
      t.index ['updated_at'], name: 'index_sessions_on_updated_at', using: :btree
    end

    create_table 'static_permissions', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'title', limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.index ['title'], name: 'static_permissions_title_index', unique: true, using: :btree
    end

    create_table 'status_histories', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'time'
      t.string  'key',                           collation: 'utf8_general_ci'
      t.float   'value', limit: 24, null: false
      t.index ['time', 'key'], name: 'index_status_histories_on_time_and_key', using: :btree
      t.index ['key'], name: 'index_status_histories_on_key', using: :btree
    end

    create_table 'status_messages', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'deleted_at'
      t.text     'message',    limit: 65_535, collation: 'utf8_general_ci'
      t.integer  'user_id'
      t.integer  'severity'
      t.index ['user_id'], name: 'user', using: :btree
      t.index ['deleted_at', 'created_at'], name: 'index_status_messages_on_deleted_at_and_created_at', using: :btree
    end

    create_table 'taggings', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'taggable_id'
      t.string  'taggable_type', collation: 'utf8_general_ci'
      t.integer 'tag_id'
      t.integer 'user_id'
      t.index ['taggable_id', 'taggable_type', 'tag_id', 'user_id'], name: 'taggings_taggable_id_index', unique: true, using: :btree
      t.index ['taggable_type'], name: 'index_taggings_on_taggable_type', using: :btree
      t.index ['tag_id'], name: 'tag_id', using: :btree
      t.index ['user_id'], name: 'user_id', using: :btree
    end

    create_table 'tags', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string   'name',       null: false, collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.index ['name'], name: 'tags_name_unique_index', unique: true, using: :btree
    end

    create_table 'tokens', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string  'string'
      t.integer 'user_id',    null: false
      t.integer 'package_id'
      t.index ['user_id'], name: 'user_id', using: :btree
      t.index ['package_id'], name: 'package_id', using: :btree
      t.index ['string'], name: 'index_tokens_on_string', unique: true, using: :btree
    end

    create_table 'updateinfo_counter', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'maintenance_db_project_id'
      t.integer 'day'
      t.integer 'month'
      t.integer 'year'
      t.integer 'counter',                   default: 0
    end

    create_table 'user_registrations', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer  'user_id',                  default: 0, null: false
      t.text     'token',      limit: 65_535,             null: false, collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'expires_at'
      t.index ['expires_at'], name: 'user_registrations_expires_at_index', using: :btree
      t.index ['user_id'], name: 'user_registrations_user_id_index', unique: true, using: :btree
    end

    create_table 'users', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.datetime 'last_logged_in_at'
      t.integer  'login_failure_count',               default: 0,            null: false
      t.text     'login',               limit: 65_535
      t.string   'email',               limit: 200,   default: '',           null: false, collation: 'utf8_general_ci'
      t.string   'realname',            limit: 200,   default: '',           null: false, collation: 'utf8_general_ci'
      t.string   'password',            limit: 100,   default: '',           null: false, collation: 'utf8_general_ci'
      t.string   'password_hash_type',  limit: 20,    default: '',           null: false, collation: 'utf8_general_ci'
      t.string   'password_salt',       limit: 10,    default: '1234512345', null: false, collation: 'utf8_general_ci'
      t.string   'password_crypted',    limit: 64,                                        collation: 'utf8_general_ci'
      t.integer  'state',                             default: 1,            null: false
      t.text     'adminnote',           limit: 65_535,                                     collation: 'utf8_general_ci'
      t.index ['login'], name: 'users_login_index', unique: true, length: { login: 255 }, using: :btree
      t.index ['password'], name: 'users_password_index', using: :btree
    end

    create_table 'watched_projects', force: :cascade, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'user_id',    default: 0, null: false
      t.integer 'project_id',             null: false
      t.index ['user_id'], name: 'watched_projects_users_fk_1', using: :btree
    end

    execute 'ALTER TABLE `schema_migrations` CHARACTER SET utf8 COLLATE=utf8_bin;'
    execute 'ALTER TABLE `schema_migrations` CHANGE `version` `version` varchar(255) CHARACTER SET utf8 NOT NULL;'
    execute 'ALTER TABLE `schema_migrations` CHANGE `version` `version` varchar(255) CHARACTER SET utf8 NOT NULL;'
    execute 'ALTER TABLE `schema_migrations` DROP PRIMARY KEY;'
    add_index :schema_migrations, [:version], name: 'unique_schema_migrations', unique: true
    execute 'ALTER TABLE groups_users CHANGE id id INT(11) AUTO_INCREMENT NOT NULL AFTER email;'
    execute 'ALTER TABLE repository_architectures CHANGE id id INT(11) AUTO_INCREMENT NOT NULL AFTER position;'

    add_foreign_key 'attrib_allowed_values', 'attrib_types', name: 'attrib_allowed_values_ibfk_1'
    add_foreign_key 'attrib_default_values', 'attrib_types', name: 'attrib_default_values_ibfk_1'
    add_foreign_key 'attrib_issues', 'attribs', name: 'attrib_issues_ibfk_1'
    add_foreign_key 'attrib_issues', 'issues', name: 'attrib_issues_ibfk_2'
    add_foreign_key 'attrib_namespace_modifiable_bies', 'attrib_namespaces', name: 'attrib_namespace_modifiable_bies_ibfk_1'
    add_foreign_key 'attrib_namespace_modifiable_bies', 'groups', name: 'attrib_namespace_modifiable_bies_ibfk_5'
    add_foreign_key 'attrib_namespace_modifiable_bies', 'users', name: 'attrib_namespace_modifiable_bies_ibfk_4'
    add_foreign_key 'attrib_type_modifiable_bies', 'groups', name: 'attrib_type_modifiable_bies_ibfk_2'
    add_foreign_key 'attrib_type_modifiable_bies', 'roles', name: 'attrib_type_modifiable_bies_ibfk_3'
    add_foreign_key 'attrib_type_modifiable_bies', 'users', name: 'attrib_type_modifiable_bies_ibfk_1'
    add_foreign_key 'attrib_types', 'attrib_namespaces', name: 'attrib_types_ibfk_1'
    add_foreign_key 'attrib_values', 'attribs', name: 'attrib_values_ibfk_1'
    add_foreign_key 'attribs', 'attrib_types', name: 'attribs_ibfk_1'
    add_foreign_key 'attribs', 'packages', name: 'attribs_ibfk_2'
    add_foreign_key 'attribs', 'projects', name: 'attribs_ibfk_3'
    add_foreign_key 'backend_packages', 'packages', column: 'links_to_id', name: 'backend_packages_ibfk_2'
    add_foreign_key 'backend_packages', 'packages', name: 'backend_packages_ibfk_1'
    add_foreign_key 'bs_request_action_accept_infos', 'bs_request_actions', name: 'bs_request_action_accept_infos_ibfk_1'
    add_foreign_key 'bs_request_actions', 'bs_requests', name: 'bs_request_actions_ibfk_1'
    add_foreign_key 'bs_request_histories', 'bs_requests', name: 'bs_request_histories_ibfk_1'
    add_foreign_key 'channel_binaries', 'architectures', name: 'channel_binaries_ibfk_4'
    add_foreign_key 'channel_binaries', 'channel_binary_lists', name: 'channel_binaries_ibfk_1'
    add_foreign_key 'channel_binaries', 'projects', name: 'channel_binaries_ibfk_2'
    add_foreign_key 'channel_binaries', 'repositories', name: 'channel_binaries_ibfk_3'
    add_foreign_key 'channel_binary_lists', 'architectures', name: 'channel_binary_lists_ibfk_4'
    add_foreign_key 'channel_binary_lists', 'channels', name: 'channel_binary_lists_ibfk_1'
    add_foreign_key 'channel_binary_lists', 'projects', name: 'channel_binary_lists_ibfk_2'
    add_foreign_key 'channel_binary_lists', 'repositories', name: 'channel_binary_lists_ibfk_3'
    add_foreign_key 'channel_targets', 'channels', name: 'channel_targets_ibfk_1'
    add_foreign_key 'channel_targets', 'repositories', name: 'channel_targets_ibfk_2'
    add_foreign_key 'channels', 'packages', name: 'channels_ibfk_1'
    add_foreign_key 'comments', 'comments', column: 'parent_id', name: 'comments_ibfk_4'
    add_foreign_key 'comments', 'packages', name: 'comments_ibfk_2'
    add_foreign_key 'comments', 'projects', name: 'comments_ibfk_3'
    add_foreign_key 'comments', 'users', name: 'comments_ibfk_1'
    add_foreign_key 'db_projects_tags', 'projects', column: 'db_project_id', name: 'db_projects_tags_ibfk_1'
    add_foreign_key 'db_projects_tags', 'tags', name: 'db_projects_tags_ibfk_2'
    add_foreign_key 'flags', 'architectures', name: 'flags_ibfk_3'
    add_foreign_key 'flags', 'packages', name: 'flags_ibfk_5'
    add_foreign_key 'flags', 'projects', name: 'flags_ibfk_4'
    add_foreign_key 'groups_roles', 'groups', name: 'groups_roles_ibfk_1'
    add_foreign_key 'groups_roles', 'roles', name: 'groups_roles_ibfk_2'
    add_foreign_key 'groups_users', 'groups', name: 'groups_users_ibfk_1'
    add_foreign_key 'groups_users', 'users', name: 'groups_users_ibfk_2'
    add_foreign_key 'issues', 'issue_trackers', name: 'issues_ibfk_2'
    add_foreign_key 'issues', 'users', column: 'owner_id', name: 'issues_ibfk_1'
    add_foreign_key 'package_issues', 'issues', name: 'package_issues_ibfk_2'
    add_foreign_key 'package_issues', 'packages', name: 'package_issues_ibfk_1'
    add_foreign_key 'package_kinds', 'packages', name: 'package_kinds_ibfk_1'
    add_foreign_key 'packages', 'packages', column: 'develpackage_id', name: 'packages_ibfk_3'
    add_foreign_key 'packages', 'projects', name: 'packages_ibfk_4'
    add_foreign_key 'path_elements', 'repositories', column: 'parent_id', name: 'path_elements_ibfk_1'
    add_foreign_key 'path_elements', 'repositories', name: 'path_elements_ibfk_2'
    add_foreign_key 'product_channels', 'channels', name: 'product_channels_ibfk_1'
    add_foreign_key 'product_channels', 'products', name: 'product_channels_ibfk_2'
    add_foreign_key 'product_update_repositories', 'products', name: 'product_update_repositories_ibfk_1'
    add_foreign_key 'product_update_repositories', 'repositories', name: 'product_update_repositories_ibfk_2'
    add_foreign_key 'products', 'packages', name: 'products_ibfk_1'
    add_foreign_key 'project_log_entries', 'projects', name: 'project_log_entries_ibfk_1'
    add_foreign_key 'projects', 'db_project_types', column: 'type_id', name: 'projects_ibfk_1'
    add_foreign_key 'ratings', 'users', name: 'ratings_ibfk_1'
    add_foreign_key 'relationships', 'groups', name: 'relationships_ibfk_3'
    add_foreign_key 'relationships', 'packages', name: 'relationships_ibfk_5'
    add_foreign_key 'relationships', 'projects', name: 'relationships_ibfk_4'
    add_foreign_key 'relationships', 'roles', name: 'relationships_ibfk_1'
    add_foreign_key 'relationships', 'users', name: 'relationships_ibfk_2'
    add_foreign_key 'release_targets', 'repositories', column: 'target_repository_id', name: 'release_targets_ibfk_2'
    add_foreign_key 'release_targets', 'repositories', name: 'release_targets_ibfk_1'
    add_foreign_key 'repositories', 'projects', column: 'db_project_id', name: 'repositories_ibfk_1'
    add_foreign_key 'repositories', 'repositories', column: 'hostsystem_id', name: 'repositories_ibfk_2'
    add_foreign_key 'repository_architectures', 'architectures', name: 'repository_architectures_ibfk_2'
    add_foreign_key 'repository_architectures', 'repositories', name: 'repository_architectures_ibfk_1'
    add_foreign_key 'reviews', 'bs_requests', name: 'reviews_ibfk_1'
    add_foreign_key 'roles', 'roles', column: 'parent_id', name: 'roles_ibfk_1'
    add_foreign_key 'roles_static_permissions', 'roles', name: 'roles_static_permissions_ibfk_1'
    add_foreign_key 'roles_static_permissions', 'static_permissions', name: 'roles_static_permissions_ibfk_2'
    add_foreign_key 'roles_users', 'roles', name: 'roles_users_ibfk_2'
    add_foreign_key 'roles_users', 'users', name: 'roles_users_ibfk_1'
    add_foreign_key 'taggings', 'tags', name: 'taggings_ibfk_1'
    add_foreign_key 'taggings', 'users', name: 'taggings_ibfk_2'
    add_foreign_key 'tokens', 'packages', name: 'tokens_ibfk_2'
    add_foreign_key 'tokens', 'users', name: 'tokens_ibfk_1'
    add_foreign_key 'user_registrations', 'users', name: 'user_registrations_ibfk_1'
    add_foreign_key 'watched_projects', 'users', name: 'watched_projects_ibfk_1'
    # rubocop:enable Layout/ExtraSpacing

    execute <<-SQL
      INSERT INTO `architectures` VALUES (1,'aarch64',0),(2,'armv4l',0),(3,'armv5l',0),(4,'armv6l',0),(5,'armv7l',1),(6,'armv5el',0),(7,'armv6el',0),(8,'armv7el',0),(9,'armv8el',0),(10,'hppa',0),(11,'i586',1),(12,'i686',0),(13,'ia64',0),(14,'local',0),(15,'m68k',0),(16,'mips',0),(17,'mips32',0),(18,'mips64',0),(19,'ppc',0),(20,'ppc64',0),(21,'ppc64p7',0),(22,'ppc64le',0),(23,'s390',0),(24,'s390x',0),(25,'sparc',0),(26,'sparc64',0),(27,'sparc64v',0),(28,'sparcv8',0),(29,'sparcv9',0),(30,'sparcv9v',0),(31,'x86_64',1);
    SQL

    execute <<-SQL
      INSERT INTO `users` VALUES (1,'2014-04-10 07:43:53','2014-04-10 07:43:53',NULL,0,'Admin','root@localhost','OBS Instance Superuser','8dc6e1b924b5375fc825e1541ffe6c8d','md5','ED7B9A1ON7','osQq6OKjF0f8I',2,NULL),(2,'2014-04-10 07:43:53','2014-04-10 07:43:53',NULL,0,'_nobody_','nobody@localhost','Anonymous User','65a8f83fa5cd130e57dc6ce026e047d6','md5','EYyHjNODSr','osEJSjdDGtlBY',3,NULL);
    SQL

    execute <<-SQL
      INSERT INTO `roles` VALUES (1,'Admin',NULL,1),(2,'maintainer',NULL,0),(3,'bugowner',NULL,0),(4,'reviewer',NULL,0),(5,'downloader',NULL,0),(6,'reader',NULL,0);
    SQL

    execute <<-SQL
      INSERT INTO `attrib_namespaces` VALUES (1,'OBS');
    SQL

    execute <<-SQL
      INSERT INTO `attrib_namespace_modifiable_bies` VALUES (1,1,1,NULL);
    SQL

    execute <<-SQL
      INSERT INTO `attrib_types` VALUES (1,'VeryImportantProject',NULL,NULL,0,1,0),(2,'UpdateProject',NULL,NULL,1,1,0),(3,'RejectRequests',NULL,NULL,NULL,1,0),(4,'ApprovedRequestSource',NULL,NULL,0,1,0),(5,'Maintained',NULL,NULL,0,1,0),(6,'MaintenanceProject',NULL,NULL,0,1,0),(7,'MaintenanceIdTemplate',NULL,NULL,1,1,0),(8,'ScreenShots',NULL,NULL,NULL,1,0),(9,'OwnerRootProject',NULL,NULL,NULL,1,0),(10,'RequestCloned',NULL,NULL,1,1,0),(11,'ProjectStatusPackageFailComment',NULL,NULL,1,1,0),(12,'InitializeDevelPackage',NULL,NULL,0,1,0),(13,'BranchTarget',NULL,NULL,0,1,0),(14,'BranchRepositoriesFromProject',NULL,NULL,1,1,0),(15,'AutoCleanup',NULL,NULL,1,1,0),(16,'Issues',NULL,NULL,0,1,0),(17,'QualityCategory',NULL,NULL,1,1,0);
    SQL

    execute <<-SQL
      INSERT INTO `attrib_allowed_values` VALUES (1,9,'DisableDevel'),(2,9,'BugownerOnly'),(3,17,'Stable'),(4,17,'Testing'),(5,17,'Development'),(6,17,'Private');
    SQL

    execute <<-SQL
      INSERT INTO `attrib_type_modifiable_bies` VALUES (1,1,1,NULL,NULL),(2,2,1,NULL,NULL),(3,3,1,NULL,NULL),(4,4,1,NULL,NULL),(5,5,1,NULL,NULL),(6,6,1,NULL,NULL),(7,7,1,NULL,NULL),(8,8,1,NULL,NULL),(9,9,1,NULL,NULL),(10,10,NULL,NULL,2),(11,11,NULL,NULL,2),(12,12,NULL,NULL,2),(13,13,NULL,NULL,2),(14,14,NULL,NULL,2),(15,15,NULL,NULL,2),(16,16,NULL,NULL,2),(17,16,NULL,NULL,3),(18,16,NULL,NULL,4),(19,17,NULL,NULL,2);
    SQL

    execute <<-SQL
      INSERT INTO `configurations` VALUES (1,'Open Build Service','  <p class=\"description\">\n    The <a href=\"http://openbuildservice.org\">Open Build Service (OBS)</a>\n    is an open and complete distribution development platform that provides a transparent infrastructure for development of Linux distributions, used by openSUSE, MeeGo and other distributions.\n    Supporting also Fedora, Debian, Ubuntu, RedHat and other Linux distributions.\n  </p>\n  <p class=\"description\">\n    The OBS is developed under the umbrella of the <a href=\"http://www.opensuse.org\">openSUSE project</a>. Please find further informations on the <a href=\"http://wiki.opensuse.org/openSUSE:Build_Service\">openSUSE Project wiki pages</a>.\n  </p>\n\n  <p class=\"description\">\n    The Open Build Service developer team is greeting you. In case you use your OBS productive in your facility, please do us a favor and add yourself at <a href=\"http://wiki.opensuse.org/openSUSE:Build_Service_installations\">this wiki page</a>. Have fun and fast build times!\n  </p>\n','2014-04-10 07:43:54','2014-04-10 07:43:54','private','allow',1,0,1,0,1,0,1,1,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'unconfigured@openbuildservice.org');
    SQL

    execute <<-SQL
      INSERT INTO `db_project_types` VALUES (1,'standard'),(2,'maintenance'),(3,'maintenance_incident'),(4,'maintenance_release');
    SQL

    execute <<-SQL
      INSERT INTO `issue_trackers` VALUES (1,'boost','trac','Boost Trac','https://svn.boost.org/trac/boost/','https://svn.boost.org/trac/boost/ticket/@@@','boost#(\\d+)',NULL,NULL,'boost#@@@','2014-04-10 07:43:54',0),(2,'bco','bugzilla','Clutter Project Bugzilla','http://bugzilla.clutter-project.org/','http://bugzilla.clutter-project.org/show_bug.cgi?id=@@@','bco#(\\d+)',NULL,NULL,'bco#@@@','2014-04-10 07:43:54',0),(3,'RT','other','CPAN Bugs','https://rt.cpan.org/','http://rt.cpan.org/Public/Bug/Display.html?id=@@@','RT#(\\d+)',NULL,NULL,'RT#@@@','2014-04-10 07:43:55',0),(4,'cve','cve','CVE Numbers','http://cve.mitre.org/','http://cve.mitre.org/cgi-bin/cvename.cgi?name=@@@','(CVE-\\d\\d\\d\\d-\\d+)',NULL,NULL,'@@@','2014-04-10 07:43:55',0),(5,'deb','bugzilla','Debian Bugzilla','http://bugs.debian.org/','http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=@@@','deb#(\\d+)',NULL,NULL,'deb#@@@','2014-04-10 07:43:55',0),(6,'fdo','bugzilla','Freedesktop.org Bugzilla','https://bugs.freedesktop.org/','https://bugs.freedesktop.org/show_bug.cgi?id=@@@','fdo#(\\d+)',NULL,NULL,'fdo#@@@','2014-04-10 07:43:55',0),(7,'GCC','bugzilla','GCC Bugzilla','http://gcc.gnu.org/bugzilla/','http://gcc.gnu.org/bugzilla/show_bug.cgi?id=@@@','GCC#(\\d+)',NULL,NULL,'GCC#@@@','2014-04-10 07:43:55',0),(8,'bgo','bugzilla','Gnome Bugzilla','https://bugzilla.gnome.org/','https://bugzilla.gnome.org/show_bug.cgi?id=@@@','bgo#(\\d+)',NULL,NULL,'bgo#@@@','2014-04-10 07:43:55',0),(9,'bio','bugzilla','Icculus.org Bugzilla','https://bugzilla.icculus.org/','https://bugzilla.icculus.org/show_bug.cgi?id=@@@','bio#(\\d+)',NULL,NULL,'bio#@@@','2014-04-10 07:43:55',0),(10,'bko','bugzilla','Kernel.org Bugzilla','https://bugzilla.kernel.org/','https://bugzilla.kernel.org/show_bug.cgi?id=@@@','(?:Kernel|K|bko)#(\\d+)',NULL,NULL,'bko#@@@','2014-04-10 07:43:55',0),(11,'kde','bugzilla','KDE Bugzilla','https://bugs.kde.org/','https://bugs.kde.org/show_bug.cgi?id=@@@','kde#(\\d+)',NULL,NULL,'kde#@@@','2014-04-10 07:43:55',0),(12,'lp','launchpad','Launchpad.net Bugtracker','https://bugs.launchpad.net/bugs/','https://bugs.launchpad.net/bugs/@@@','b?lp#(\\d+)',NULL,NULL,'lp#@@@','2014-04-10 07:43:55',0),(13,'Meego','bugzilla','Meego Bugs','https://bugs.meego.com/','https://bugs.meego.com/show_bug.cgi?id=@@@','Meego#(\\d+)',NULL,NULL,'Meego#@@@','2014-04-10 07:43:55',0),(14,'bmo','bugzilla','Mozilla Bugzilla','https://bugzilla.mozilla.org/','https://bugzilla.mozilla.org/show_bug.cgi?id=@@@','bmo#(\\d+)',NULL,NULL,'bmo#@@@','2014-04-10 07:43:55',0),(15,'bnc','bugzilla','Novell Bugzilla','https://bugzilla.novell.com/','https://bugzilla.novell.com/show_bug.cgi?id=@@@','(?:bnc|BNC)\\s*[#:]\\s*(\\d+)',NULL,NULL,'bnc#@@@','2014-04-10 07:43:55',1),(16,'ITS','other','OpenLDAP Issue Tracker','http://www.openldap.org/its/','http://www.openldap.org/its/index.cgi/Contrib?id=@@@','ITS#(\\d+)',NULL,NULL,'ITS#@@@','2014-04-10 07:43:55',0),(17,'i','bugzilla','OpenOffice.org Bugzilla','http://openoffice.org/bugzilla/','http://openoffice.org/bugzilla/show_bug.cgi?id=@@@','i#(\\d+)',NULL,NULL,'boost#@@@','2014-04-10 07:43:55',0),(18,'fate','fate','openSUSE Feature Database','https://features.opensuse.org/','https://features.opensuse.org/@@@','(?:fate|Fate|FATE)\\s*#\\s*(\\d+)',NULL,NULL,'fate#@@@','2014-04-10 07:43:55',0),(19,'rh','bugzilla','RedHat Bugzilla','https://bugzilla.redhat.com/','https://bugzilla.redhat.com/show_bug.cgi?id=@@@','rh#(\\d+)',NULL,NULL,'rh#@@@','2014-04-10 07:43:55',0),(20,'bso','bugzilla','Samba Bugzilla','https://bugzilla.samba.org/','https://bugzilla.samba.org/show_bug.cgi?id=@@@','bso#(\\d+)',NULL,NULL,'bso#@@@','2014-04-10 07:43:55',0),(21,'sf','sourceforge','SourceForge.net Tracker','http://sf.net/support/','http://sf.net/support/tracker.php?aid=@@@','sf#(\\d+)',NULL,NULL,'sf#@@@','2014-04-10 07:43:55',0),(22,'Xamarin','bugzilla','Xamarin Bugzilla','http://bugzilla.xamarin.com/index.cgi','http://bugzilla.xamarin.com/show_bug.cgi?id=@@@','Xamarin#(\\d+)',NULL,NULL,'Xamarin#@@@','2014-04-10 07:43:55',0),(23,'bxo','bugzilla','XFCE Bugzilla','https://bugzilla.xfce.org/','https://bugzilla.xfce.org/show_bug.cgi?id=@@@','bxo#(\\d+)',NULL,NULL,'bxo#@@@','2014-04-10 07:43:55',0);
    SQL

    execute <<-SQL
      INSERT INTO `projects` VALUES (1,'deleted',NULL,NULL,'2014-04-10 07:43:54','2014-04-10 07:43:54',NULL,NULL,1,NULL,NULL,1);
    SQL

    execute <<-SQL
      INSERT INTO `repositories` VALUES (1,1,'deleted',NULL,NULL,NULL,NULL,NULL);
    SQL

    execute <<-SQL
      INSERT INTO `roles_users` VALUES (1,1,'2014-04-10 07:43:53');
    SQL

    execute <<-SQL
      INSERT INTO `static_permissions` VALUES (5,'access'),(12,'change_package'),(10,'change_project'),(13,'create_package'),(11,'create_project'),(3,'download_binaries'),(8,'global_change_package'),(6,'global_change_project'),(9,'global_create_package'),(7,'global_create_project'),(2,'set_download_counters'),(4,'source_access'),(1,'status_message_create');
    SQL

    execute <<-SQL
      INSERT INTO `roles_static_permissions` VALUES (1,1),(1,2),(1,3),(5,3),(1,4),(6,4),(1,5),(6,5),(1,6),(1,7),(1,8),(1,9),(1,10),(2,10),(1,11),(2,11),(1,12),(2,12),(1,13),(2,13);
    SQL
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable MethodLength
  # rubocop:enable Metrics/LineLength

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
