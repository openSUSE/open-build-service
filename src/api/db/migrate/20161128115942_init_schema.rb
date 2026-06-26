class InitSchema < ActiveRecord::Migration[6.0]
  def up
    create_table 'architectures', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
      t.boolean 'available', default: false
      t.index ['name'], name: 'arch_name_index', unique: true
    end
    create_table 'architectures_distributions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'distribution_id'
      t.integer 'architecture_id'
    end
    create_table 'attrib_allowed_values', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id', null: false
      t.text 'value', collation: 'utf8_general_ci'
      t.index ['attrib_type_id'], name: 'attrib_type_id'
    end
    create_table 'attrib_default_values', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id', null: false
      t.text 'value', null: false, collation: 'utf8_general_ci'
      t.integer 'position', null: false
      t.index ['attrib_type_id'], name: 'attrib_type_id'
    end
    create_table 'attrib_issues', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'attrib_id', null: false
      t.integer 'issue_id', null: false
      t.index ['attrib_id', 'issue_id'], name: 'index_attrib_issues_on_attrib_id_and_issue_id', unique: true
      t.index ['issue_id'], name: 'issue_id'
    end
    create_table 'attrib_namespace_modifiable_bies', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'attrib_namespace_id', null: false
      t.integer 'user_id'
      t.integer 'group_id'
      t.index ['attrib_namespace_id', 'user_id', 'group_id'], name: 'attrib_namespace_user_role_all_index', unique: true
      t.index ['attrib_namespace_id'], name: 'index_attrib_namespace_modifiable_bies_on_attrib_namespace_id'
      t.index ['group_id'], name: 'bs_group_id'
      t.index ['user_id'], name: 'bs_user_id'
    end
    create_table 'attrib_namespaces', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', collation: 'utf8_general_ci'
      t.index ['name'], name: 'index_attrib_namespaces_on_name'
    end
    create_table 'attrib_type_modifiable_bies', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'attrib_type_id', null: false
      t.integer 'user_id'
      t.integer 'group_id'
      t.integer 'role_id'
      t.index ['attrib_type_id', 'user_id', 'group_id', 'role_id'], name: 'attrib_type_user_role_all_index', unique: true
      t.index ['group_id'], name: 'group_id'
      t.index ['role_id'], name: 'role_id'
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'attrib_types', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
      t.string 'description', collation: 'utf8_general_ci'
      t.string 'type', collation: 'utf8_general_ci'
      t.integer 'value_count'
      t.integer 'attrib_namespace_id', null: false
      t.boolean 'issue_list', default: false
      t.index ['attrib_namespace_id', 'name'], name: 'index_attrib_types_on_attrib_namespace_id_and_name', unique: true
      t.index ['attrib_namespace_id'], name: 'attrib_namespace_id'
      t.index ['name'], name: 'index_attrib_types_on_name'
    end
    create_table 'attrib_values', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_id', null: false
      t.text 'value', null: false, collation: 'utf8_general_ci'
      t.integer 'position', null: false
      t.index ['attrib_id'], name: 'index_attrib_values_on_attrib_id'
    end
    create_table 'attribs', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'attrib_type_id', null: false
      t.integer 'package_id'
      t.string 'binary', collation: 'utf8_general_ci'
      t.integer 'project_id'
      t.index ['attrib_type_id', 'package_id', 'project_id', 'binary'], name: 'attribs_index', unique: true
      t.index ['attrib_type_id', 'project_id', 'package_id', 'binary'], name: 'attribs_on_proj_and_pack', unique: true
      t.index ['package_id'], name: 'index_attribs_on_package_id'
      t.index ['project_id'], name: 'index_attribs_on_project_id'
    end
    create_table 'backend_infos', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'key', null: false
      t.string 'value', null: false
      t.datetime 'created_at'
      t.datetime 'updated_at'
    end
    create_table 'backend_packages', primary_key: 'package_id', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'links_to_id'
      t.datetime 'updated_at'
      t.string 'srcmd5'
      t.string 'changesmd5'
      t.string 'verifymd5'
      t.string 'expandedmd5'
      t.text 'error'
      t.datetime 'maxmtime'
      t.index ['links_to_id'], name: 'index_backend_packages_on_links_to_id'
    end
    create_table 'binary_releases', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'repository_id', null: false
      t.column 'operation', "enum('added','removed','modified')", default: 'added'
      t.datetime 'obsolete_time'
      t.integer 'release_package_id'
      t.string 'binary_name', null: false, collation: 'utf8_general_ci'
      t.string 'binary_epoch', limit: 64
      t.string 'binary_version', limit: 64, null: false
      t.string 'binary_release', limit: 64, null: false
      t.string 'binary_arch', limit: 64, null: false
      t.string 'binary_disturl'
      t.datetime 'binary_buildtime'
      t.datetime 'binary_releasetime', null: false
      t.string 'binary_supportstatus'
      t.string 'binary_maintainer'
      t.string 'medium', collation: 'utf8_general_ci'
      t.string 'binary_updateinfo', collation: 'utf8_general_ci'
      t.string 'binary_updateinfo_version'
      t.datetime 'modify_time'
      t.index ['binary_name', 'binary_arch'], name: 'index_binary_releases_on_binary_name_and_binary_arch'
      t.index ['binary_name', 'binary_epoch', 'binary_version', 'binary_release', 'binary_arch'], name: 'exact_search_index'
      t.index ['binary_name'], name: 'index_binary_releases_on_binary_name'
      t.index ['binary_updateinfo'], name: 'index_binary_releases_on_binary_updateinfo'
      t.index ['medium'], name: 'index_binary_releases_on_medium'
      t.index ['release_package_id'], name: 'release_package_id'
      t.index ['repository_id', 'binary_name'], name: 'ra_name_index'
    end
    create_table 'blacklist_tags', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', collation: 'utf8_general_ci'
      t.datetime 'created_at'
    end
    create_table 'bs_request_action_accept_infos', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'bs_request_action_id'
      t.string 'rev'
      t.string 'srcmd5'
      t.string 'xsrcmd5'
      t.string 'osrcmd5'
      t.string 'oxsrcmd5'
      t.datetime 'created_at'
      t.string 'oproject'
      t.string 'opackage'
      t.index ['bs_request_action_id'], name: 'bs_request_action_id'
    end
    create_table 'bs_request_actions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'bs_request_id'
      t.string 'type'
      t.string 'target_project', collation: 'utf8_unicode_ci'
      t.string 'target_package', collation: 'utf8_unicode_ci'
      t.string 'target_releaseproject', collation: 'utf8_unicode_ci'
      t.string 'source_project', collation: 'utf8_unicode_ci'
      t.string 'source_package', collation: 'utf8_unicode_ci'
      t.string 'source_rev', collation: 'utf8_unicode_ci'
      t.string 'sourceupdate', collation: 'utf8_unicode_ci'
      t.boolean 'updatelink', default: false
      t.string 'person_name', collation: 'utf8_unicode_ci'
      t.string 'group_name', collation: 'utf8_unicode_ci'
      t.string 'role', collation: 'utf8_unicode_ci'
      t.datetime 'created_at'
      t.string 'target_repository'
      t.boolean 'makeoriginolder', default: false
      t.index ['bs_request_id'], name: 'bs_request_id'
      t.index ['source_package'], name: 'index_bs_request_actions_on_source_package'
      t.index ['source_project'], name: 'index_bs_request_actions_on_source_project'
      t.index ['target_package'], name: 'index_bs_request_actions_on_target_package'
      t.index ['target_project', 'source_project'], name: 'index_bs_request_actions_on_target_project_and_source_project'
      t.index ['target_project'], name: 'index_bs_request_actions_on_target_project'
    end
    create_table 'bs_request_counter', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'counter', default: 1
    end
    create_table 'bs_requests', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.text 'description'
      t.string 'creator', collation: 'utf8_unicode_ci'
      t.string 'state', collation: 'utf8_unicode_ci'
      t.text 'comment'
      t.string 'commenter', collation: 'utf8_unicode_ci'
      t.integer 'superseded_by'
      t.datetime 'created_at', null: false
      t.datetime 'updated_at', null: false
      t.datetime 'accept_at'
      t.column 'priority', "enum('critical','important','moderate','low')", default: 'moderate'
      t.integer 'number'
      t.datetime 'updated_when'
      t.index ['creator'], name: 'index_bs_requests_on_creator'
      t.index ['number'], name: 'index_bs_requests_on_number', unique: true
      t.index ['state'], name: 'index_bs_requests_on_state'
      t.index ['superseded_by'], name: 'index_bs_requests_on_superseded_by'
    end
    create_table 'cache_lines', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'key', null: false
      t.string 'package'
      t.string 'project'
      t.integer 'request'
      t.datetime 'created_at'
      t.index ['project', 'package'], name: 'index_cache_lines_on_project_and_package'
      t.index ['project'], name: 'index_cache_lines_on_project'
    end
    create_table 'channel_binaries', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'name', null: false
      t.integer 'channel_binary_list_id', null: false
      t.integer 'project_id'
      t.integer 'repository_id'
      t.integer 'architecture_id'
      t.string 'package'
      t.string 'binaryarch'
      t.string 'supportstatus'
      t.index ['architecture_id'], name: 'architecture_id'
      t.index ['channel_binary_list_id'], name: 'channel_binary_list_id'
      t.index ['name', 'channel_binary_list_id'], name: 'index_channel_binaries_on_name_and_channel_binary_list_id'
      t.index ['project_id', 'package'], name: 'index_channel_binaries_on_project_id_and_package'
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'channel_binary_lists', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'channel_id', null: false
      t.integer 'project_id'
      t.integer 'repository_id'
      t.integer 'architecture_id'
      t.index ['architecture_id'], name: 'architecture_id'
      t.index ['channel_id'], name: 'channel_id'
      t.index ['project_id'], name: 'project_id'
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'channel_targets', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'channel_id', null: false
      t.integer 'repository_id', null: false
      t.string 'prefix'
      t.string 'id_template'
      t.boolean 'disabled', default: false
      t.boolean 'requires_issue'
      t.index ['channel_id', 'repository_id'], name: 'index_channel_targets_on_channel_id_and_repository_id', unique: true
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'channels', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'package_id', null: false
      t.index ['package_id'], name: 'index_unique', unique: true
      t.index ['package_id'], name: 'package_id'
    end
    create_table 'comments', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.text 'body'
      t.integer 'parent_id'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.integer 'user_id', null: false
      t.string 'commentable_type'
      t.integer 'commentable_id'
      t.index ['commentable_type', 'commentable_id'], name: 'index_comments_on_commentable_type_and_commentable_id'
      t.index ['parent_id'], name: 'parent_id'
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'configurations', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'title', default: ''
      t.text 'description', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string 'name', default: ''
      t.column 'registration', "enum('allow','confirmation','deny')", default: 'allow'
      t.boolean 'anonymous', default: true
      t.boolean 'default_access_disabled', default: false
      t.boolean 'allow_user_to_create_home_project', default: true
      t.boolean 'disallow_group_creation', default: false
      t.boolean 'change_password', default: true
      t.boolean 'hide_private_options', default: false
      t.boolean 'gravatar', default: true
      t.boolean 'enforce_project_keys', default: true
      t.boolean 'download_on_demand', default: true
      t.string 'download_url'
      t.string 'ymp_url'
      t.string 'bugzilla_url'
      t.string 'http_proxy'
      t.string 'no_proxy'
      t.string 'theme'
      t.string 'obs_url'
      t.integer 'cleanup_after_days'
      t.string 'admin_email', default: 'unconfigured@openbuildservice.org'
      t.boolean 'cleanup_empty_projects', default: true
      t.boolean 'disable_publish_for_branches', default: true
      t.string 'default_tracker', default: 'bnc'
      t.string 'api_url'
    end
    create_table 'db_projects_tags', id: false, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'db_project_id', null: false
      t.integer 'tag_id', null: false
      t.index ['db_project_id', 'tag_id'], name: 'projects_tags_all_index', unique: true
      t.index ['tag_id'], name: 'tag_id'
    end
    create_table 'delayed_jobs', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'priority', default: 0
      t.integer 'attempts', default: 0
      t.text 'handler', collation: 'utf8_general_ci'
      t.text 'last_error', collation: 'utf8_general_ci'
      t.datetime 'run_at'
      t.datetime 'locked_at'
      t.datetime 'failed_at'
      t.string 'locked_by', collation: 'utf8_general_ci'
      t.string 'queue', collation: 'utf8_general_ci'
      t.index ['queue'], name: 'index_delayed_jobs_on_queue'
    end
    create_table 'distribution_icons', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'url', null: false
      t.integer 'width'
      t.integer 'height'
    end
    create_table 'distribution_icons_distributions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'distribution_id'
      t.integer 'distribution_icon_id'
    end
    create_table 'distributions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'vendor', null: false
      t.string 'version', null: false
      t.string 'name', null: false
      t.string 'project', null: false
      t.string 'reponame', null: false
      t.string 'repository', null: false
      t.string 'link'
    end
    create_table 'download_repositories', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'repository_id', null: false
      t.string 'arch', null: false
      t.string 'url', null: false
      t.string 'repotype'
      t.string 'archfilter'
      t.string 'masterurl'
      t.string 'mastersslfingerprint'
      t.text 'pubkey'
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'event_subscriptions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'eventtype', null: false
      t.string 'receiver_role', null: false
      t.integer 'user_id'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.boolean 'receive', default: true, null: false
      t.integer 'group_id'
      t.index ['group_id'], name: 'index_event_subscriptions_on_group_id'
      t.index ['user_id'], name: 'index_event_subscriptions_on_user_id'
    end
    create_table 'events', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'eventtype', null: false
      t.text 'payload'
      t.boolean 'queued', default: false, null: false
      t.integer 'lock_version', default: 0, null: false
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.boolean 'project_logged', default: false
      t.integer 'undone_jobs', default: 0
      t.boolean 'mails_sent', default: false
      t.index ['created_at'], name: 'index_events_on_created_at'
      t.index ['eventtype'], name: 'index_events_on_eventtype'
      t.index ['project_logged'], name: 'index_events_on_project_logged'
      t.index ['queued'], name: 'index_events_on_queued'
    end
    create_table 'flags', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.column 'status', "enum('enable','disable')", null: false, collation: 'utf8_general_ci'
      t.string 'repo', collation: 'utf8_general_ci'
      t.integer 'project_id'
      t.integer 'package_id'
      t.integer 'architecture_id'
      t.integer 'position', null: false
      t.column 'flag', "enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock')", null: false, collation: 'utf8_general_ci'
      t.index ['architecture_id'], name: 'architecture_id'
      t.index ['flag'], name: 'index_flags_on_flag'
      t.index ['package_id'], name: 'index_flags_on_package_id'
      t.index ['project_id'], name: 'index_flags_on_project_id'
    end
    create_table 'group_maintainers', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'group_id'
      t.integer 'user_id'
      t.index ['group_id'], name: 'group_id'
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'group_request_requests', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'bs_request_action_group_id'
      t.integer 'bs_request_id'
      t.index ['bs_request_action_group_id'], name: 'index_group_request_requests_on_bs_request_action_group_id'
      t.index ['bs_request_id'], name: 'index_group_request_requests_on_bs_request_id'
    end
    create_table 'groups', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string 'title', limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.integer 'parent_id'
      t.string 'email'
      t.index ['parent_id'], name: 'groups_parent_id_index'
      t.index ['title'], name: 'index_groups_on_title'
    end
    create_table 'groups_roles', id: false, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'group_id', default: 0, null: false
      t.integer 'role_id', default: 0, null: false
      t.datetime 'created_at'
      t.index ['group_id', 'role_id'], name: 'groups_roles_all_index', unique: true
      t.index ['role_id'], name: 'role_id'
    end
    create_table 'groups_users', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'group_id', default: 0, null: false
      t.integer 'user_id', default: 0, null: false
      t.datetime 'created_at'
      t.boolean 'email', default: true
      t.index ['group_id', 'user_id'], name: 'groups_users_all_index', unique: true
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'history_elements', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.string 'type', null: false, collation: 'utf8_general_ci'
      t.integer 'op_object_id', null: false
      t.datetime 'created_at', null: false
      t.integer 'user_id', null: false
      t.string 'description_extension'
      t.text 'comment'
      t.index ['created_at'], name: 'index_history_elements_on_created_at'
      t.index ['op_object_id', 'type'], name: 'index_search'
      t.index ['op_object_id'], name: 'index_history_elements_on_op_object_id'
      t.index ['type'], name: 'index_history_elements_on_type'
    end
    create_table 'incident_counter', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'maintenance_db_project_id'
      t.integer 'counter', default: 0
    end
    create_table 'incident_updateinfo_counter_values', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'updateinfo_counter_id', null: false
      t.integer 'project_id', null: false
      t.integer 'value', null: false
      t.datetime 'released_at', null: false
      t.index ['project_id'], name: 'project_id'
      t.index ['updateinfo_counter_id', 'project_id'], name: 'uniq_id_index'
    end
    create_table 'issue_trackers', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
      t.column 'kind', "enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github')", null: false
      t.string 'description', collation: 'utf8_general_ci'
      t.string 'url', null: false, collation: 'utf8_general_ci'
      t.string 'show_url', collation: 'utf8_general_ci'
      t.string 'regex', null: false, collation: 'utf8_general_ci'
      t.string 'user', collation: 'utf8_general_ci'
      t.string 'password', collation: 'utf8_general_ci'
      t.text 'label', null: false, collation: 'utf8_general_ci'
      t.datetime 'issues_updated', null: false
      t.boolean 'enable_fetch', default: false
    end
    create_table 'issues', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
      t.integer 'issue_tracker_id', null: false
      t.string 'summary', collation: 'utf8_general_ci'
      t.integer 'owner_id'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.column 'state', "enum('OPEN','CLOSED','UNKNOWN')", collation: 'utf8_general_ci'
      t.index ['issue_tracker_id'], name: 'issue_tracker_id'
      t.index ['name', 'issue_tracker_id'], name: 'index_issues_on_name_and_issue_tracker_id'
      t.index ['owner_id'], name: 'owner_id'
    end
    create_table 'linked_projects', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id', null: false
      t.integer 'linked_db_project_id'
      t.integer 'position'
      t.string 'linked_remote_project_name', collation: 'utf8_general_ci'
      t.index ['db_project_id', 'linked_db_project_id'], name: 'linked_projects_index', unique: true
    end
    create_table 'maintained_projects', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'project_id', null: false
      t.integer 'maintenance_project_id', null: false
      t.index ['maintenance_project_id'], name: 'maintenance_project_id'
      t.index ['project_id', 'maintenance_project_id'], name: 'uniq_index', unique: true
    end
    create_table 'maintenance_incidents', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id'
      t.integer 'maintenance_db_project_id'
      t.string 'updateinfo_id', collation: 'utf8_general_ci'
      t.integer 'incident_id'
      t.datetime 'released_at'
      t.index ['db_project_id'], name: 'index_maintenance_incidents_on_db_project_id'
      t.index ['maintenance_db_project_id'], name: 'index_maintenance_incidents_on_maintenance_db_project_id'
    end
    create_table 'messages', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_object_id'
      t.string 'db_object_type', collation: 'utf8_general_ci'
      t.integer 'user_id'
      t.datetime 'created_at'
      t.boolean 'send_mail'
      t.datetime 'sent_at'
      t.boolean 'private'
      t.integer 'severity'
      t.text 'text', collation: 'utf8_general_ci'
      t.index ['db_object_id'], name: 'object'
      t.index ['user_id'], name: 'user'
    end
    create_table 'package_issues', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'package_id', null: false
      t.integer 'issue_id', null: false
      t.column 'change', "enum('added','deleted','changed','kept')"
      t.index ['issue_id'], name: 'index_package_issues_on_issue_id'
      t.index ['package_id', 'issue_id'], name: 'index_package_issues_on_package_id_and_issue_id'
      t.index ['package_id'], name: 'index_package_issues_on_package_id'
    end
    create_table 'package_kinds', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'package_id'
      t.column 'kind', "enum('patchinfo','aggregate','link','channel','product')", null: false
      t.index ['package_id'], name: 'index_package_kinds_on_package_id'
    end
    create_table 'packages', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'project_id', null: false
      t.text 'name'
      t.string 'title', collation: 'utf8_general_ci'
      t.text 'description', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string 'url', collation: 'utf8_general_ci'
      t.integer 'update_counter', default: 0
      t.float 'activity_index', default: 100.0
      t.string 'bcntsynctag', collation: 'utf8_general_ci'
      t.integer 'develpackage_id'
      t.boolean 'delta', default: true, null: false
      t.string 'releasename'
      t.index ['develpackage_id'], name: 'devel_package_id_index'
      t.index ['project_id', 'name'], name: 'packages_all_index', unique: true, length: { name: 255 }
      t.index ['project_id'], name: 'index_packages_on_project_id'
      t.index ['updated_at'], name: 'updated_at_index'
    end
    create_table 'path_elements', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'parent_id', null: false
      t.integer 'repository_id', null: false
      t.integer 'position', null: false
      t.index ['parent_id', 'repository_id'], name: 'parent_repository_index', unique: true
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'product_channels', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'product_id', null: false
      t.integer 'channel_id', null: false
      t.index ['channel_id', 'product_id'], name: 'index_product_channels_on_channel_id_and_product_id', unique: true
      t.index ['product_id'], name: 'product_id'
    end
    create_table 'product_media', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'product_id'
      t.integer 'repository_id'
      t.integer 'arch_filter_id'
      t.string 'name', collation: 'utf8_general_ci'
      t.index ['arch_filter_id'], name: 'index_product_media_on_arch_filter_id'
      t.index ['name'], name: 'index_product_media_on_name'
      t.index ['product_id', 'repository_id', 'name', 'arch_filter_id'], name: 'index_unique', unique: true
      t.index ['product_id'], name: 'index_product_media_on_product_id'
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'product_update_repositories', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4' do |t|
      t.integer 'product_id'
      t.integer 'repository_id'
      t.integer 'arch_filter_id'
      t.index ['arch_filter_id'], name: 'index_product_update_repositories_on_arch_filter_id'
      t.index ['product_id', 'repository_id', 'arch_filter_id'], name: 'index_unique', unique: true
      t.index ['product_id'], name: 'index_product_update_repositories_on_product_id'
      t.index ['repository_id'], name: 'repository_id'
    end
    create_table 'products', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'name', null: false
      t.integer 'package_id', null: false
      t.string 'cpe'
      t.string 'version'
      t.string 'baseversion'
      t.string 'patchlevel'
      t.string 'release'
      t.index ['name', 'package_id'], name: 'index_products_on_name_and_package_id', unique: true
      t.index ['package_id'], name: 'package_id'
    end
    create_table 'project_log_entries', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'project_id'
      t.string 'user_name'
      t.string 'package_name'
      t.integer 'bs_request_id'
      t.datetime 'datetime'
      t.string 'event_type'
      t.text 'additional_info'
      t.index ['bs_request_id'], name: 'index_project_log_entries_on_bs_request_id'
      t.index ['datetime'], name: 'index_project_log_entries_on_datetime'
      t.index ['event_type'], name: 'index_project_log_entries_on_event_type'
      t.index ['package_name'], name: 'index_project_log_entries_on_package_name'
      t.index ['project_id'], name: 'project_id'
      t.index ['user_name'], name: 'index_project_log_entries_on_user_name'
    end
    create_table 'projects', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.text 'name'
      t.string 'title', collation: 'utf8_general_ci'
      t.text 'description', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.string 'remoteurl', collation: 'utf8_general_ci'
      t.string 'remoteproject', collation: 'utf8_general_ci'
      t.integer 'develproject_id'
      t.boolean 'delta', default: true, null: false
      t.column 'kind', "enum('standard','maintenance','maintenance_incident','maintenance_release')", default: 'standard'
      t.string 'url'
      t.index ['develproject_id'], name: 'devel_project_id_index'
      t.index ['name'], name: 'projects_name_index', unique: true, length: 255
      t.index ['updated_at'], name: 'updated_at_index'
    end
    create_table 'ratings', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'score'
      t.integer 'db_object_id'
      t.string 'db_object_type', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.integer 'user_id'
      t.index ['db_object_id'], name: 'object'
      t.index ['user_id'], name: 'user'
    end
    create_table 'relationships', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'package_id'
      t.integer 'project_id'
      t.integer 'role_id', null: false
      t.integer 'user_id'
      t.integer 'group_id'
      t.index ['group_id'], name: 'group_id'
      t.index ['package_id', 'role_id', 'group_id'], name: 'index_relationships_on_package_id_and_role_id_and_group_id', unique: true
      t.index ['package_id', 'role_id', 'user_id'], name: 'index_relationships_on_package_id_and_role_id_and_user_id', unique: true
      t.index ['project_id', 'role_id', 'group_id'], name: 'index_relationships_on_project_id_and_role_id_and_group_id', unique: true
      t.index ['project_id', 'role_id', 'user_id'], name: 'index_relationships_on_project_id_and_role_id_and_user_id', unique: true
      t.index ['role_id'], name: 'role_id'
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'release_targets', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'repository_id', null: false
      t.integer 'target_repository_id', null: false
      t.column 'trigger', "enum('manual','allsucceeded','maintenance')"
      t.index ['repository_id'], name: 'repository_id_index'
      t.index ['target_repository_id'], name: 'index_release_targets_on_target_repository_id'
    end
    create_table 'repositories', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'db_project_id', null: false
      t.string 'name', null: false
      t.string 'remote_project_name', collation: 'utf8_general_ci'
      t.column 'rebuild', "enum('transitive','direct','local')", collation: 'utf8_general_ci'
      t.column 'block', "enum('all','local','never')", collation: 'utf8_general_ci'
      t.column 'linkedbuild', "enum('off','localdep','all')", collation: 'utf8_general_ci'
      t.integer 'hostsystem_id'
      t.index ['db_project_id', 'name', 'remote_project_name'], name: 'projects_name_index', unique: true
      t.index ['hostsystem_id'], name: 'hostsystem_id'
      t.index ['remote_project_name'], name: 'remote_project_name_index'
    end
    create_table 'repository_architectures', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'repository_id', null: false
      t.integer 'architecture_id', null: false
      t.integer 'position', default: 0, null: false
      t.index ['architecture_id'], name: 'architecture_id'
      t.index ['repository_id', 'architecture_id'], name: 'arch_repo_index', unique: true
    end
    create_table 'reviews', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.integer 'bs_request_id'
      t.string 'creator'
      t.string 'reviewer'
      t.text 'reason'
      t.string 'state'
      t.string 'by_user'
      t.string 'by_group'
      t.string 'by_project'
      t.string 'by_package'
      t.datetime 'created_at', null: false
      t.datetime 'updated_at', null: false
      t.index ['bs_request_id'], name: 'bs_request_id'
      t.index ['by_group'], name: 'index_reviews_on_by_group'
      t.index ['by_package', 'by_project'], name: 'index_reviews_on_by_package_and_by_project'
      t.index ['by_project'], name: 'index_reviews_on_by_project'
      t.index ['by_user'], name: 'index_reviews_on_by_user'
      t.index ['creator'], name: 'index_reviews_on_creator'
      t.index ['reviewer'], name: 'index_reviews_on_reviewer'
      t.index ['state', 'by_project'], name: 'index_reviews_on_state_and_by_project'
      t.index ['state', 'by_user'], name: 'index_reviews_on_state_and_by_user'
      t.index ['state'], name: 'index_reviews_on_state'
    end
    create_table 'roles', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'title', limit: 100, default: '', null: false, collation: 'utf8_general_ci'
      t.integer 'parent_id'
      t.boolean 'global', default: false
      t.index ['parent_id'], name: 'roles_parent_id_index'
    end
    create_table 'roles_static_permissions', id: false, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'role_id', default: 0, null: false
      t.integer 'static_permission_id', default: 0, null: false
      t.index ['role_id'], name: 'role_id'
      t.index ['static_permission_id', 'role_id'], name: 'roles_static_permissions_all_index', unique: true
    end
    create_table 'roles_users', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'user_id', default: 0, null: false
      t.integer 'role_id', default: 0, null: false
      t.datetime 'created_at'
      t.index ['role_id'], name: 'role_id'
      t.index ['user_id', 'role_id'], name: 'roles_users_all_index', unique: true
    end
    create_table 'sessions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'session_id', null: false
      t.text 'data'
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.index ['session_id'], name: 'index_sessions_on_session_id'
      t.index ['updated_at'], name: 'index_sessions_on_updated_at'
    end
    create_table 'static_permissions', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'title', limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.index ['title'], name: 'static_permissions_title_index', unique: true
    end
    create_table 'status_histories', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'time'
      t.string 'key', collation: 'utf8_general_ci'
      t.float 'value', null: false
      t.index ['key'], name: 'index_status_histories_on_key'
      t.index ['time', 'key'], name: 'index_status_histories_on_time_and_key'
    end
    create_table 'status_messages', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'deleted_at'
      t.text 'message', collation: 'utf8_general_ci'
      t.integer 'user_id'
      t.integer 'severity'
      t.index ['deleted_at', 'created_at'], name: 'index_status_messages_on_deleted_at_and_created_at'
      t.index ['user_id'], name: 'user'
    end
    create_table 'taggings', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'taggable_id'
      t.string 'taggable_type', collation: 'utf8_general_ci'
      t.integer 'tag_id'
      t.integer 'user_id'
      t.index ['tag_id'], name: 'tag_id'
      t.index ['taggable_id', 'taggable_type', 'tag_id', 'user_id'], name: 'taggings_taggable_id_index', unique: true
      t.index ['taggable_type'], name: 'index_taggings_on_taggable_type'
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'tags', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.string 'name', null: false, collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.index ['name'], name: 'tags_name_unique_index', unique: true
    end
    create_table 'tokens', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci' do |t|
      t.string 'string'
      t.integer 'user_id', null: false
      t.integer 'package_id'
      t.index ['package_id'], name: 'package_id'
      t.index ['string'], name: 'index_tokens_on_string', unique: true
      t.index ['user_id'], name: 'user_id'
    end
    create_table 'updateinfo_counters', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer 'maintenance_db_project_id'
      t.integer 'day'
      t.integer 'month'
      t.integer 'year'
      t.integer 'counter', default: 0
    end
    create_table 'user_registrations', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'user_id', default: 0, null: false
      t.text 'token', null: false, collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.datetime 'expires_at'
      t.index ['expires_at'], name: 'user_registrations_expires_at_index'
      t.index ['user_id'], name: 'user_registrations_user_id_index', unique: true
    end
    create_table 'users', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.datetime 'last_logged_in_at'
      t.integer 'login_failure_count', default: 0, null: false
      t.text 'login'
      t.string 'email', limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.string 'realname', limit: 200, default: '', null: false, collation: 'utf8_general_ci'
      t.string 'password', limit: 100, default: '', null: false, collation: 'utf8_general_ci'
      t.string 'password_hash_type', limit: 20, default: '', null: false, collation: 'utf8_general_ci'
      t.string 'password_salt', limit: 10, default: '1234512345', null: false, collation: 'utf8_general_ci'
      t.string 'password_crypted', limit: 64, collation: 'utf8_general_ci'
      t.text 'adminnote', collation: 'utf8_general_ci'
      t.column 'state', "enum('unconfirmed','confirmed','locked','deleted','subaccount')", default: 'unconfirmed'
      t.integer 'owner_id'
      t.index ['login'], name: 'users_login_index', unique: true, length: 255
      t.index ['password'], name: 'users_password_index'
    end
    create_table 'watched_projects', id: :integer, options: 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin' do |t|
      t.integer 'user_id', default: 0, null: false
      t.integer 'project_id', null: false
      t.index ['user_id'], name: 'watched_projects_users_fk_1'
    end
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
    add_foreign_key 'binary_releases', 'packages', column: 'release_package_id', name: 'binary_releases_ibfk_2'
    add_foreign_key 'binary_releases', 'repositories', name: 'binary_releases_ibfk_1'
    add_foreign_key 'bs_request_action_accept_infos', 'bs_request_actions', name: 'bs_request_action_accept_infos_ibfk_1'
    add_foreign_key 'bs_request_actions', 'bs_requests', name: 'bs_request_actions_ibfk_1'
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
    add_foreign_key 'comments', 'users', name: 'comments_ibfk_1'
    add_foreign_key 'db_projects_tags', 'projects', column: 'db_project_id', name: 'db_projects_tags_ibfk_1'
    add_foreign_key 'db_projects_tags', 'tags', name: 'db_projects_tags_ibfk_2'
    add_foreign_key 'download_repositories', 'repositories', name: 'download_repositories_ibfk_1'
    add_foreign_key 'flags', 'architectures', name: 'flags_ibfk_3'
    add_foreign_key 'flags', 'packages', name: 'flags_ibfk_5'
    add_foreign_key 'flags', 'projects', name: 'flags_ibfk_4'
    add_foreign_key 'group_maintainers', 'groups', name: 'group_maintainers_ibfk_1'
    add_foreign_key 'group_maintainers', 'users', name: 'group_maintainers_ibfk_2'
    add_foreign_key 'groups_roles', 'groups', name: 'groups_roles_ibfk_1'
    add_foreign_key 'groups_roles', 'roles', name: 'groups_roles_ibfk_2'
    add_foreign_key 'groups_users', 'groups', name: 'groups_users_ibfk_1'
    add_foreign_key 'groups_users', 'users', name: 'groups_users_ibfk_2'
    add_foreign_key 'incident_updateinfo_counter_values', 'projects', name: 'incident_updateinfo_counter_values_ibfk_1'
    add_foreign_key 'issues', 'issue_trackers', name: 'issues_ibfk_2'
    add_foreign_key 'issues', 'users', column: 'owner_id', name: 'issues_ibfk_1'
    add_foreign_key 'maintained_projects', 'projects', column: 'maintenance_project_id', name: 'maintained_projects_ibfk_2'
    add_foreign_key 'maintained_projects', 'projects', name: 'maintained_projects_ibfk_1'
    add_foreign_key 'package_issues', 'issues', name: 'package_issues_ibfk_2'
    add_foreign_key 'package_issues', 'packages', name: 'package_issues_ibfk_1'
    add_foreign_key 'package_kinds', 'packages', name: 'package_kinds_ibfk_1'
    add_foreign_key 'packages', 'packages', column: 'develpackage_id', name: 'packages_ibfk_3'
    add_foreign_key 'packages', 'projects', name: 'packages_ibfk_4'
    add_foreign_key 'path_elements', 'repositories', column: 'parent_id', name: 'path_elements_ibfk_1'
    add_foreign_key 'path_elements', 'repositories', name: 'path_elements_ibfk_2'
    add_foreign_key 'product_channels', 'channels', name: 'product_channels_ibfk_1'
    add_foreign_key 'product_channels', 'products', name: 'product_channels_ibfk_2'
    add_foreign_key 'product_media', 'architectures', column: 'arch_filter_id', name: 'product_media_ibfk_3'
    add_foreign_key 'product_media', 'products', name: 'product_media_ibfk_1'
    add_foreign_key 'product_media', 'repositories', name: 'product_media_ibfk_2'
    add_foreign_key 'product_update_repositories', 'architectures', column: 'arch_filter_id', name: 'product_update_repositories_ibfk_3'
    add_foreign_key 'product_update_repositories', 'products', name: 'product_update_repositories_ibfk_1'
    add_foreign_key 'product_update_repositories', 'repositories', name: 'product_update_repositories_ibfk_2'
    add_foreign_key 'products', 'packages', name: 'products_ibfk_1'
    add_foreign_key 'project_log_entries', 'projects', name: 'project_log_entries_ibfk_1'
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
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'The initial migration is not revertable'
  end
end
