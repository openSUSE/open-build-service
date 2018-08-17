CREATE TABLE `announcements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `announcements_users` (
  `user_id` int(11) DEFAULT NULL,
  `announcement_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  KEY `index_announcements_users_on_user_id` (`user_id`),
  KEY `index_announcements_users_on_announcement_id` (`announcement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) CHARACTER SET utf8 NOT NULL,
  `value` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `architectures` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `available` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `arch_name_index` (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `architectures_distributions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `distribution_id` int(11) DEFAULT NULL,
  `architecture_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_allowed_values` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_type_id` int(11) NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `attrib_type_id` (`attrib_type_id`) USING BTREE,
  CONSTRAINT `attrib_allowed_values_ibfk_1` FOREIGN KEY (`attrib_type_id`) REFERENCES `attrib_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_default_values` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_type_id` int(11) NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `position` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `attrib_type_id` (`attrib_type_id`) USING BTREE,
  CONSTRAINT `attrib_default_values_ibfk_1` FOREIGN KEY (`attrib_type_id`) REFERENCES `attrib_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_issues` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_id` int(11) NOT NULL,
  `issue_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_attrib_issues_on_attrib_id_and_issue_id` (`attrib_id`,`issue_id`) USING BTREE,
  KEY `issue_id` (`issue_id`) USING BTREE,
  CONSTRAINT `attrib_issues_ibfk_1` FOREIGN KEY (`attrib_id`) REFERENCES `attribs` (`id`),
  CONSTRAINT `attrib_issues_ibfk_2` FOREIGN KEY (`issue_id`) REFERENCES `issues` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_namespace_modifiable_bies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_namespace_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `attrib_namespace_user_role_all_index` (`attrib_namespace_id`,`user_id`,`group_id`) USING BTREE,
  KEY `bs_user_id` (`user_id`) USING BTREE,
  KEY `bs_group_id` (`group_id`) USING BTREE,
  CONSTRAINT `attrib_namespace_modifiable_bies_ibfk_1` FOREIGN KEY (`attrib_namespace_id`) REFERENCES `attrib_namespaces` (`id`),
  CONSTRAINT `attrib_namespace_modifiable_bies_ibfk_4` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `attrib_namespace_modifiable_bies_ibfk_5` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_namespaces` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_attrib_namespaces_on_name` (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_type_modifiable_bies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_type_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `attrib_type_user_role_all_index` (`attrib_type_id`,`user_id`,`group_id`,`role_id`) USING BTREE,
  KEY `user_id` (`user_id`) USING BTREE,
  KEY `group_id` (`group_id`) USING BTREE,
  KEY `role_id` (`role_id`) USING BTREE,
  CONSTRAINT `attrib_type_modifiable_bies_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `attrib_type_modifiable_bies_ibfk_2` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`),
  CONSTRAINT `attrib_type_modifiable_bies_ibfk_3` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_types` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `description` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `value_count` int(11) DEFAULT NULL,
  `attrib_namespace_id` int(11) NOT NULL,
  `issue_list` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_attrib_types_on_attrib_namespace_id_and_name` (`attrib_namespace_id`,`name`) USING BTREE,
  KEY `index_attrib_types_on_name` (`name`) USING BTREE,
  CONSTRAINT `attrib_types_ibfk_1` FOREIGN KEY (`attrib_namespace_id`) REFERENCES `attrib_namespaces` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attrib_values` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_id` int(11) NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `position` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_attrib_values_on_attrib_id` (`attrib_id`) USING BTREE,
  CONSTRAINT `attrib_values_ibfk_1` FOREIGN KEY (`attrib_id`) REFERENCES `attribs` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `attribs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attrib_type_id` int(11) NOT NULL,
  `package_id` int(11) DEFAULT NULL,
  `binary` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `project_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `attribs_index` (`attrib_type_id`,`package_id`,`project_id`,`binary`) USING BTREE,
  UNIQUE KEY `attribs_on_proj_and_pack` (`attrib_type_id`,`project_id`,`package_id`,`binary`) USING BTREE,
  KEY `index_attribs_on_package_id` (`package_id`) USING BTREE,
  KEY `index_attribs_on_project_id` (`project_id`) USING BTREE,
  CONSTRAINT `attribs_ibfk_1` FOREIGN KEY (`attrib_type_id`) REFERENCES `attrib_types` (`id`),
  CONSTRAINT `attribs_ibfk_2` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`),
  CONSTRAINT `attribs_ibfk_3` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `backend_infos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `key` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `value` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `backend_packages` (
  `package_id` int(11) NOT NULL AUTO_INCREMENT,
  `links_to_id` int(11) DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `srcmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `changesmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `verifymd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `expandedmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `error` text COLLATE utf8mb4_unicode_ci,
  `maxmtime` datetime DEFAULT NULL,
  PRIMARY KEY (`package_id`),
  KEY `index_backend_packages_on_links_to_id` (`links_to_id`) USING BTREE,
  CONSTRAINT `backend_packages_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`),
  CONSTRAINT `backend_packages_ibfk_2` FOREIGN KEY (`links_to_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `binary_releases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `repository_id` int(11) NOT NULL,
  `operation` enum('added','removed','modified') CHARACTER SET utf8 DEFAULT 'added',
  `obsolete_time` datetime DEFAULT NULL,
  `release_package_id` int(11) DEFAULT NULL,
  `binary_name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `binary_epoch` varchar(64) CHARACTER SET utf8 DEFAULT NULL,
  `binary_version` varchar(64) CHARACTER SET utf8 NOT NULL,
  `binary_release` varchar(64) CHARACTER SET utf8 NOT NULL,
  `binary_arch` varchar(64) CHARACTER SET utf8 NOT NULL,
  `binary_disturl` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `binary_buildtime` datetime DEFAULT NULL,
  `binary_releasetime` datetime NOT NULL,
  `binary_supportstatus` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `binary_maintainer` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `medium` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `binary_updateinfo` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `binary_updateinfo_version` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `modify_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ra_name_index` (`repository_id`,`binary_name`),
  KEY `exact_search_index` (`binary_name`,`binary_epoch`,`binary_version`,`binary_release`,`binary_arch`),
  KEY `release_package_id` (`release_package_id`),
  KEY `index_binary_releases_on_binary_updateinfo` (`binary_updateinfo`),
  KEY `index_binary_releases_on_medium` (`medium`),
  KEY `index_binary_releases_on_binary_name_and_binary_arch` (`binary_name`,`binary_arch`),
  CONSTRAINT `binary_releases_ibfk_1` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `binary_releases_ibfk_2` FOREIGN KEY (`release_package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `bs_request_action_accept_infos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bs_request_action_id` int(11) DEFAULT NULL,
  `rev` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `srcmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `xsrcmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `osrcmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `oxsrcmd5` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `oproject` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `opackage` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `bs_request_action_id` (`bs_request_action_id`) USING BTREE,
  CONSTRAINT `bs_request_action_accept_infos_ibfk_1` FOREIGN KEY (`bs_request_action_id`) REFERENCES `bs_request_actions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `bs_request_actions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bs_request_id` int(11) DEFAULT NULL,
  `type` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `target_project` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `target_package` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `target_releaseproject` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `source_project` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `source_package` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `source_rev` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `sourceupdate` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `updatelink` tinyint(1) DEFAULT '0',
  `person_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `group_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `role` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `target_repository` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `makeoriginolder` tinyint(1) DEFAULT '0',
  `target_package_id` int(11) DEFAULT NULL,
  `target_project_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `bs_request_id` (`bs_request_id`) USING BTREE,
  KEY `index_bs_request_actions_on_target_project` (`target_project`) USING BTREE,
  KEY `index_bs_request_actions_on_target_package` (`target_package`) USING BTREE,
  KEY `index_bs_request_actions_on_source_project` (`source_project`) USING BTREE,
  KEY `index_bs_request_actions_on_source_package` (`source_package`) USING BTREE,
  KEY `index_bs_request_actions_on_bs_request_id_and_target_project_id` (`bs_request_id`,`target_project_id`),
  KEY `index_bs_request_actions_on_bs_request_id_and_target_package_id` (`bs_request_id`,`target_package_id`),
  KEY `index_bs_request_actions_on_target_project_id` (`target_project_id`),
  KEY `index_bs_request_actions_on_target_package_id` (`target_package_id`),
  CONSTRAINT `bs_request_actions_ibfk_1` FOREIGN KEY (`bs_request_id`) REFERENCES `bs_requests` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `bs_request_counter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `counter` int(11) DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `bs_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` text COLLATE utf8mb4_unicode_ci,
  `creator` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `state` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci,
  `commenter` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `superseded_by` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `accept_at` datetime DEFAULT NULL,
  `priority` enum('critical','important','moderate','low') CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'moderate',
  `number` int(11) DEFAULT NULL,
  `updated_when` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_bs_requests_on_number` (`number`),
  KEY `index_bs_requests_on_creator` (`creator`) USING BTREE,
  KEY `index_bs_requests_on_state` (`state`) USING BTREE,
  KEY `index_bs_requests_on_superseded_by` (`superseded_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `channel_binaries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `channel_binary_list_id` int(11) NOT NULL,
  `project_id` int(11) DEFAULT NULL,
  `repository_id` int(11) DEFAULT NULL,
  `architecture_id` int(11) DEFAULT NULL,
  `package` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `binaryarch` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `supportstatus` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_channel_binaries_on_project_id_and_package` (`project_id`,`package`) USING BTREE,
  KEY `channel_binary_list_id` (`channel_binary_list_id`) USING BTREE,
  KEY `repository_id` (`repository_id`) USING BTREE,
  KEY `architecture_id` (`architecture_id`) USING BTREE,
  KEY `index_channel_binaries_on_name_and_channel_binary_list_id` (`name`,`channel_binary_list_id`) USING BTREE,
  CONSTRAINT `channel_binaries_ibfk_1` FOREIGN KEY (`channel_binary_list_id`) REFERENCES `channel_binary_lists` (`id`),
  CONSTRAINT `channel_binaries_ibfk_2` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `channel_binaries_ibfk_3` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `channel_binaries_ibfk_4` FOREIGN KEY (`architecture_id`) REFERENCES `architectures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `channel_binary_lists` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `channel_id` int(11) NOT NULL,
  `project_id` int(11) DEFAULT NULL,
  `repository_id` int(11) DEFAULT NULL,
  `architecture_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `channel_id` (`channel_id`) USING BTREE,
  KEY `project_id` (`project_id`) USING BTREE,
  KEY `repository_id` (`repository_id`) USING BTREE,
  KEY `architecture_id` (`architecture_id`) USING BTREE,
  CONSTRAINT `channel_binary_lists_ibfk_1` FOREIGN KEY (`channel_id`) REFERENCES `channels` (`id`),
  CONSTRAINT `channel_binary_lists_ibfk_2` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `channel_binary_lists_ibfk_3` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `channel_binary_lists_ibfk_4` FOREIGN KEY (`architecture_id`) REFERENCES `architectures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `channel_targets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `channel_id` int(11) NOT NULL,
  `repository_id` int(11) NOT NULL,
  `prefix` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `id_template` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `disabled` tinyint(1) DEFAULT '0',
  `requires_issue` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_channel_targets_on_channel_id_and_repository_id` (`channel_id`,`repository_id`) USING BTREE,
  KEY `repository_id` (`repository_id`) USING BTREE,
  CONSTRAINT `channel_targets_ibfk_1` FOREIGN KEY (`channel_id`) REFERENCES `channels` (`id`),
  CONSTRAINT `channel_targets_ibfk_2` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `channels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `package_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_unique` (`package_id`),
  CONSTRAINT `channels_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `cloud_azure_configurations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `application_id` text CHARACTER SET utf8,
  `application_key` text CHARACTER SET utf8,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cloud_azure_configurations_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `cloud_ec2_configurations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `external_id` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `arn` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cloud_ec2_configurations_on_external_id_and_arn` (`external_id`,`arn`),
  KEY `index_cloud_ec2_configurations_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `cloud_user_upload_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `job_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cloud_user_upload_jobs_on_job_id` (`job_id`),
  KEY `index_cloud_user_upload_jobs_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `body` text COLLATE utf8mb4_unicode_ci,
  `parent_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `commentable_type` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `commentable_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`) USING BTREE,
  KEY `parent_id` (`parent_id`) USING BTREE,
  KEY `index_comments_on_commentable_type_and_commentable_id` (`commentable_type`,`commentable_id`),
  CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `comments_ibfk_4` FOREIGN KEY (`parent_id`) REFERENCES `comments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `configurations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT '',
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT '',
  `registration` enum('allow','confirmation','deny') CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'allow',
  `anonymous` tinyint(1) DEFAULT '1',
  `default_access_disabled` tinyint(1) DEFAULT '0',
  `allow_user_to_create_home_project` tinyint(1) DEFAULT '1',
  `disallow_group_creation` tinyint(1) DEFAULT '0',
  `change_password` tinyint(1) DEFAULT '1',
  `hide_private_options` tinyint(1) DEFAULT '0',
  `gravatar` tinyint(1) DEFAULT '1',
  `enforce_project_keys` tinyint(1) DEFAULT '0',
  `download_on_demand` tinyint(1) DEFAULT '1',
  `download_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `ymp_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `bugzilla_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `http_proxy` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `no_proxy` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `theme` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `obs_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'https://unconfigured.openbuildservice.org',
  `cleanup_after_days` int(11) DEFAULT NULL,
  `admin_email` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'unconfigured@openbuildservice.org',
  `cleanup_empty_projects` tinyint(1) DEFAULT '1',
  `disable_publish_for_branches` tinyint(1) DEFAULT '1',
  `default_tracker` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'bnc',
  `api_url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `unlisted_projects_filter` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT '^home:.+',
  `unlisted_projects_filter_description` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'home projects',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `data_migrations` (
  `version` varchar(255) CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `delayed_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `priority` int(11) DEFAULT '0',
  `attempts` int(11) DEFAULT '0',
  `handler` mediumtext CHARACTER SET utf8 COLLATE utf8_bin,
  `last_error` text COLLATE utf8mb4_unicode_ci,
  `run_at` datetime DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `failed_at` datetime DEFAULT NULL,
  `locked_by` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `queue` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_delayed_jobs_on_queue` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `distribution_icons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `width` int(11) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `distribution_icons_distributions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `distribution_id` int(11) DEFAULT NULL,
  `distribution_icon_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `distributions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vendor` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `version` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `project` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `reponame` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `repository` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `link` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `download_repositories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `repository_id` int(11) NOT NULL,
  `arch` varchar(255) CHARACTER SET utf8 NOT NULL,
  `url` varchar(255) CHARACTER SET utf8 NOT NULL,
  `repotype` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `archfilter` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `masterurl` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `mastersslfingerprint` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `pubkey` text CHARACTER SET utf8,
  PRIMARY KEY (`id`),
  KEY `repository_id` (`repository_id`),
  CONSTRAINT `download_repositories_ibfk_1` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `event_subscriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `eventtype` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `receiver_role` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `channel` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_event_subscriptions_on_user_id` (`user_id`) USING BTREE,
  KEY `index_event_subscriptions_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `eventtype` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `payload` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `undone_jobs` int(11) DEFAULT '0',
  `mails_sent` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_events_on_eventtype` (`eventtype`) USING BTREE,
  KEY `index_events_on_created_at` (`created_at`) USING BTREE,
  KEY `index_events_on_mails_sent` (`mails_sent`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` enum('enable','disable') CHARACTER SET utf8 NOT NULL,
  `repo` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `project_id` int(11) DEFAULT NULL,
  `package_id` int(11) DEFAULT NULL,
  `architecture_id` int(11) DEFAULT NULL,
  `position` int(11) NOT NULL,
  `flag` enum('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock') CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_flags_on_flag` (`flag`) USING BTREE,
  KEY `architecture_id` (`architecture_id`) USING BTREE,
  KEY `index_flags_on_package_id` (`package_id`) USING BTREE,
  KEY `index_flags_on_project_id` (`project_id`) USING BTREE,
  CONSTRAINT `flags_ibfk_3` FOREIGN KEY (`architecture_id`) REFERENCES `architectures` (`id`),
  CONSTRAINT `flags_ibfk_4` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `flags_ibfk_5` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `group_maintainers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `group_id` (`group_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `group_maintainers_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`),
  CONSTRAINT `group_maintainers_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `group_request_requests` (
  `bs_request_action_group_id` int(11) DEFAULT NULL,
  `bs_request_id` int(11) DEFAULT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  KEY `index_group_request_requests_on_bs_request_id` (`bs_request_id`) USING BTREE,
  KEY `index_group_request_requests_on_bs_request_action_group_id` (`bs_request_action_group_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `title` varchar(200) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `parent_id` int(11) DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `groups_parent_id_index` (`parent_id`) USING BTREE,
  KEY `index_groups_on_title` (`title`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `groups_roles` (
  `group_id` int(11) NOT NULL DEFAULT '0',
  `role_id` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  UNIQUE KEY `groups_roles_all_index` (`group_id`,`role_id`) USING BTREE,
  KEY `role_id` (`role_id`) USING BTREE,
  CONSTRAINT `groups_roles_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`),
  CONSTRAINT `groups_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `groups_users` (
  `group_id` int(11) NOT NULL DEFAULT '0',
  `user_id` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `email` tinyint(1) DEFAULT '1',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `groups_users_all_index` (`group_id`,`user_id`) USING BTREE,
  KEY `user_id` (`user_id`) USING BTREE,
  CONSTRAINT `groups_users_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`),
  CONSTRAINT `groups_users_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `history_elements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) CHARACTER SET utf8 NOT NULL,
  `op_object_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  `user_id` int(11) NOT NULL,
  `description_extension` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_history_elements_on_created_at` (`created_at`),
  KEY `index_history_elements_on_type` (`type`),
  KEY `index_search` (`op_object_id`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `incident_counter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `maintenance_db_project_id` int(11) DEFAULT NULL,
  `counter` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `incident_updateinfo_counter_values` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `updateinfo_counter_id` int(11) NOT NULL,
  `project_id` int(11) NOT NULL,
  `value` int(11) NOT NULL,
  `released_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `uniq_id_index` (`updateinfo_counter_id`,`project_id`),
  KEY `project_id` (`project_id`),
  CONSTRAINT `incident_updateinfo_counter_values_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `issue_trackers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `kind` enum('other','bugzilla','cve','fate','trac','launchpad','sourceforge','github') CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `description` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `url` varchar(255) CHARACTER SET utf8 NOT NULL,
  `show_url` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `regex` varchar(255) CHARACTER SET utf8 NOT NULL,
  `user` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `password` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `label` text CHARACTER SET utf8 NOT NULL,
  `issues_updated` datetime NOT NULL,
  `enable_fetch` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `issues` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `issue_tracker_id` int(11) NOT NULL,
  `summary` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `owner_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `state` enum('OPEN','CLOSED','UNKNOWN') CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner_id` (`owner_id`) USING BTREE,
  KEY `issue_tracker_id` (`issue_tracker_id`) USING BTREE,
  KEY `index_issues_on_name_and_issue_tracker_id` (`name`,`issue_tracker_id`) USING BTREE,
  CONSTRAINT `issues_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`),
  CONSTRAINT `issues_ibfk_2` FOREIGN KEY (`issue_tracker_id`) REFERENCES `issue_trackers` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_descriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image_id` int(11) DEFAULT NULL,
  `description_type` int(11) DEFAULT '0',
  `author` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `contact` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `specification` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kiwi_descriptions_on_image_id` (`image_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `md5_last_revision` varchar(32) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `use_project_repositories` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_package_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kiwi_type` int(11) NOT NULL,
  `profiles` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `pattern_type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `image_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kiwi_package_groups_on_image_id` (`image_id`),
  CONSTRAINT `fk_rails_c64a679086` FOREIGN KEY (`image_id`) REFERENCES `kiwi_images` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `arch` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `replaces` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `bootinclude` tinyint(1) DEFAULT NULL,
  `bootdelete` tinyint(1) DEFAULT NULL,
  `package_group_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kiwi_packages_on_package_group_id` (`package_group_id`),
  CONSTRAINT `fk_rails_0ecab3b2cd` FOREIGN KEY (`package_group_id`) REFERENCES `kiwi_package_groups` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image_id` int(11) DEFAULT NULL,
  `type_image` int(11) DEFAULT NULL,
  `type_containerconfig_name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `type_containerconfig_tag` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `version` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_kiwi_preferences_on_image_id` (`image_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `kiwi_repositories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image_id` int(11) DEFAULT NULL,
  `repo_type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `source_path` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `order` int(11) DEFAULT NULL,
  `priority` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `alias` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `imageinclude` tinyint(1) DEFAULT NULL,
  `password` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `prefer_license` tinyint(1) DEFAULT NULL,
  `replaceable` tinyint(1) DEFAULT NULL,
  `username` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_kiwi_repositories_on_image_id_and_order` (`image_id`,`order`),
  KEY `index_kiwi_repositories_on_image_id` (`image_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `linked_projects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `db_project_id` int(11) NOT NULL,
  `linked_db_project_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `linked_remote_project_name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `vrevmode` enum('standard','unextend','extend') CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'standard',
  PRIMARY KEY (`id`),
  UNIQUE KEY `linked_projects_index` (`db_project_id`,`linked_db_project_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `maintained_projects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `maintenance_project_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_index` (`project_id`,`maintenance_project_id`),
  KEY `maintenance_project_id` (`maintenance_project_id`),
  CONSTRAINT `maintained_projects_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `maintained_projects_ibfk_2` FOREIGN KEY (`maintenance_project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `maintenance_incidents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `db_project_id` int(11) DEFAULT NULL,
  `maintenance_db_project_id` int(11) DEFAULT NULL,
  `updateinfo_id` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `incident_id` int(11) DEFAULT NULL,
  `released_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_maintenance_incidents_on_db_project_id` (`db_project_id`) USING BTREE,
  KEY `index_maintenance_incidents_on_maintenance_db_project_id` (`maintenance_db_project_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `db_object_id` int(11) DEFAULT NULL,
  `db_object_type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `send_mail` tinyint(1) DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  `private` tinyint(1) DEFAULT NULL,
  `severity` int(11) DEFAULT NULL,
  `text` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `object` (`db_object_id`) USING BTREE,
  KEY `user` (`user_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) CHARACTER SET utf8 NOT NULL,
  `event_type` varchar(255) CHARACTER SET utf8 NOT NULL,
  `event_payload` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `subscription_receiver_role` varchar(255) CHARACTER SET utf8 NOT NULL,
  `delivered` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `subscriber_type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `subscriber_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_notifications_on_subscriber_type_and_subscriber_id` (`subscriber_type`,`subscriber_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `package_issues` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `package_id` int(11) NOT NULL,
  `issue_id` int(11) NOT NULL,
  `change` enum('added','deleted','changed','kept') CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_package_issues_on_package_id_and_issue_id` (`package_id`,`issue_id`) USING BTREE,
  KEY `index_package_issues_on_issue_id` (`issue_id`) USING BTREE,
  CONSTRAINT `package_issues_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`),
  CONSTRAINT `package_issues_ibfk_2` FOREIGN KEY (`issue_id`) REFERENCES `issues` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `package_kinds` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `package_id` int(11) DEFAULT NULL,
  `kind` enum('patchinfo','aggregate','link','channel','product') CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_package_kinds_on_package_id` (`package_id`) USING BTREE,
  CONSTRAINT `package_kinds_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `packages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `project_id` int(11) NOT NULL,
  `name` varchar(200) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `title` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `url` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `activity_index` float DEFAULT '100',
  `bcntsynctag` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `develpackage_id` int(11) DEFAULT NULL,
  `delta` tinyint(1) NOT NULL DEFAULT '1',
  `releasename` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `kiwi_image_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `packages_all_index` (`project_id`,`name`) USING BTREE,
  KEY `devel_package_id_index` (`develpackage_id`) USING BTREE,
  KEY `updated_at_index` (`updated_at`) USING BTREE,
  KEY `index_packages_on_kiwi_image_id` (`kiwi_image_id`),
  CONSTRAINT `fk_rails_9a47aff19d` FOREIGN KEY (`kiwi_image_id`) REFERENCES `kiwi_images` (`id`),
  CONSTRAINT `packages_ibfk_3` FOREIGN KEY (`develpackage_id`) REFERENCES `packages` (`id`),
  CONSTRAINT `packages_ibfk_4` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `path_elements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL,
  `repository_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `parent_repository_index` (`parent_id`,`repository_id`) USING BTREE,
  KEY `repository_id` (`repository_id`) USING BTREE,
  CONSTRAINT `path_elements_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `path_elements_ibfk_2` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `product_channels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `product_id` int(11) NOT NULL,
  `channel_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_product_channels_on_channel_id_and_product_id` (`channel_id`,`product_id`) USING BTREE,
  KEY `product_id` (`product_id`) USING BTREE,
  CONSTRAINT `product_channels_ibfk_1` FOREIGN KEY (`channel_id`) REFERENCES `channels` (`id`),
  CONSTRAINT `product_channels_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `product_media` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `product_id` int(11) DEFAULT NULL,
  `repository_id` int(11) DEFAULT NULL,
  `arch_filter_id` int(11) DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_unique` (`product_id`,`repository_id`,`name`,`arch_filter_id`),
  KEY `index_product_media_on_product_id` (`product_id`),
  KEY `index_product_media_on_arch_filter_id` (`arch_filter_id`),
  KEY `index_product_media_on_name` (`name`),
  KEY `repository_id` (`repository_id`),
  CONSTRAINT `product_media_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
  CONSTRAINT `product_media_ibfk_2` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `product_media_ibfk_3` FOREIGN KEY (`arch_filter_id`) REFERENCES `architectures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `product_update_repositories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `product_id` int(11) DEFAULT NULL,
  `repository_id` int(11) DEFAULT NULL,
  `arch_filter_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_unique` (`product_id`,`repository_id`,`arch_filter_id`),
  KEY `index_product_update_repositories_on_product_id` (`product_id`),
  KEY `index_product_update_repositories_on_arch_filter_id` (`arch_filter_id`),
  KEY `repository_id` (`repository_id`),
  CONSTRAINT `product_update_repositories_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
  CONSTRAINT `product_update_repositories_ibfk_2` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `product_update_repositories_ibfk_3` FOREIGN KEY (`arch_filter_id`) REFERENCES `architectures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `products` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `package_id` int(11) NOT NULL,
  `cpe` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `version` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `baseversion` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `patchlevel` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `release` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_products_on_name_and_package_id` (`name`,`package_id`) USING BTREE,
  KEY `package_id` (`package_id`) USING BTREE,
  CONSTRAINT `products_ibfk_1` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `project_log_entries` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `project_id` int(11) DEFAULT NULL,
  `user_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `package_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `bs_request_id` int(11) DEFAULT NULL,
  `datetime` datetime DEFAULT NULL,
  `event_type` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `additional_info` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `project_id` (`project_id`) USING BTREE,
  KEY `index_project_log_entries_on_user_name` (`user_name`) USING BTREE,
  KEY `index_project_log_entries_on_package_name` (`package_name`) USING BTREE,
  KEY `index_project_log_entries_on_bs_request_id` (`bs_request_id`) USING BTREE,
  KEY `index_project_log_entries_on_event_type` (`event_type`) USING BTREE,
  KEY `index_project_log_entries_on_datetime` (`datetime`) USING BTREE,
  CONSTRAINT `project_log_entries_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `projects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(200) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `title` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `remoteurl` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `remoteproject` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `develproject_id` int(11) DEFAULT NULL,
  `delta` tinyint(1) NOT NULL DEFAULT '1',
  `kind` enum('standard','maintenance','maintenance_incident','maintenance_release') CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'standard',
  `url` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `projects_name_index` (`name`) USING BTREE,
  KEY `updated_at_index` (`updated_at`) USING BTREE,
  KEY `devel_project_id_index` (`develproject_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `ratings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `score` int(11) DEFAULT NULL,
  `db_object_id` int(11) DEFAULT NULL,
  `db_object_type` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `object` (`db_object_id`) USING BTREE,
  KEY `user` (`user_id`) USING BTREE,
  CONSTRAINT `ratings_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `relationships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `package_id` int(11) DEFAULT NULL,
  `project_id` int(11) DEFAULT NULL,
  `role_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_relationships_on_project_id_and_role_id_and_group_id` (`project_id`,`role_id`,`group_id`) USING BTREE,
  UNIQUE KEY `index_relationships_on_project_id_and_role_id_and_user_id` (`project_id`,`role_id`,`user_id`) USING BTREE,
  UNIQUE KEY `index_relationships_on_package_id_and_role_id_and_group_id` (`package_id`,`role_id`,`group_id`) USING BTREE,
  UNIQUE KEY `index_relationships_on_package_id_and_role_id_and_user_id` (`package_id`,`role_id`,`user_id`) USING BTREE,
  KEY `role_id` (`role_id`) USING BTREE,
  KEY `user_id` (`user_id`) USING BTREE,
  KEY `group_id` (`group_id`) USING BTREE,
  CONSTRAINT `relationships_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `relationships_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `relationships_ibfk_3` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`),
  CONSTRAINT `relationships_ibfk_4` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `relationships_ibfk_5` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `release_targets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `repository_id` int(11) NOT NULL,
  `target_repository_id` int(11) NOT NULL,
  `trigger` enum('manual','allsucceeded','maintenance') CHARACTER SET utf8 DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `repository_id_index` (`repository_id`) USING BTREE,
  KEY `index_release_targets_on_target_repository_id` (`target_repository_id`) USING BTREE,
  CONSTRAINT `release_targets_ibfk_1` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `release_targets_ibfk_2` FOREIGN KEY (`target_repository_id`) REFERENCES `repositories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `repositories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `db_project_id` int(11) NOT NULL,
  `name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `remote_project_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '',
  `rebuild` enum('transitive','direct','local') CHARACTER SET utf8 DEFAULT NULL,
  `block` enum('all','local','never') CHARACTER SET utf8 DEFAULT NULL,
  `linkedbuild` enum('off','localdep','all') CHARACTER SET utf8 DEFAULT NULL,
  `hostsystem_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `projects_name_index` (`db_project_id`,`name`,`remote_project_name`) USING BTREE,
  KEY `remote_project_name_index` (`remote_project_name`) USING BTREE,
  KEY `hostsystem_id` (`hostsystem_id`) USING BTREE,
  CONSTRAINT `repositories_ibfk_1` FOREIGN KEY (`db_project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `repositories_ibfk_2` FOREIGN KEY (`hostsystem_id`) REFERENCES `repositories` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `repository_architectures` (
  `repository_id` int(11) NOT NULL,
  `architecture_id` int(11) NOT NULL,
  `position` int(11) NOT NULL DEFAULT '0',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `arch_repo_index` (`repository_id`,`architecture_id`) USING BTREE,
  KEY `architecture_id` (`architecture_id`) USING BTREE,
  CONSTRAINT `repository_architectures_ibfk_1` FOREIGN KEY (`repository_id`) REFERENCES `repositories` (`id`),
  CONSTRAINT `repository_architectures_ibfk_2` FOREIGN KEY (`architecture_id`) REFERENCES `architectures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `reviews` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `bs_request_id` int(11) DEFAULT NULL,
  `creator` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `reviewer` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `state` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `by_user` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `by_group` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `by_project` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `by_package` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `review_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `project_id` int(11) DEFAULT NULL,
  `package_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_reviews_on_creator` (`creator`) USING BTREE,
  KEY `index_reviews_on_reviewer` (`reviewer`) USING BTREE,
  KEY `index_reviews_on_by_user` (`by_user`) USING BTREE,
  KEY `index_reviews_on_by_group` (`by_group`) USING BTREE,
  KEY `index_reviews_on_by_project` (`by_project`) USING BTREE,
  KEY `index_reviews_on_by_package_and_by_project` (`by_package`,`by_project`) USING BTREE,
  KEY `bs_request_id` (`bs_request_id`) USING BTREE,
  KEY `index_reviews_on_state_and_by_project` (`state`,`by_project`) USING BTREE,
  KEY `index_reviews_on_state_and_by_user` (`state`,`by_user`) USING BTREE,
  KEY `index_reviews_on_review_id` (`review_id`),
  KEY `index_reviews_on_user_id` (`user_id`),
  KEY `index_reviews_on_group_id` (`group_id`),
  KEY `index_reviews_on_project_id` (`project_id`),
  KEY `index_reviews_on_package_id` (`package_id`),
  CONSTRAINT `fk_rails_813a4fb24f` FOREIGN KEY (`review_id`) REFERENCES `reviews` (`id`),
  CONSTRAINT `reviews_ibfk_1` FOREIGN KEY (`bs_request_id`) REFERENCES `bs_requests` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `parent_id` int(11) DEFAULT NULL,
  `global` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `roles_parent_id_index` (`parent_id`) USING BTREE,
  CONSTRAINT `roles_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `roles_static_permissions` (
  `role_id` int(11) NOT NULL DEFAULT '0',
  `static_permission_id` int(11) NOT NULL DEFAULT '0',
  UNIQUE KEY `roles_static_permissions_all_index` (`static_permission_id`,`role_id`) USING BTREE,
  KEY `role_id` (`role_id`) USING BTREE,
  CONSTRAINT `roles_static_permissions_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`),
  CONSTRAINT `roles_static_permissions_ibfk_2` FOREIGN KEY (`static_permission_id`) REFERENCES `static_permissions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `roles_users` (
  `user_id` int(11) NOT NULL DEFAULT '0',
  `role_id` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `roles_users_all_index` (`user_id`,`role_id`) USING BTREE,
  KEY `role_id` (`role_id`) USING BTREE,
  CONSTRAINT `roles_users_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `roles_users_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) CHARACTER SET utf8 NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `session_id` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `data` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_sessions_on_session_id` (`session_id`) USING BTREE,
  KEY `index_sessions_on_updated_at` (`updated_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `static_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(200) CHARACTER SET utf8 NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `static_permissions_title_index` (`title`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `status_checks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `short_description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `checkable_id` int(11) DEFAULT NULL,
  `checkable_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `status_histories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `time` int(11) DEFAULT NULL,
  `key` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  `value` float NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_status_histories_on_time_and_key` (`time`,`key`) USING BTREE,
  KEY `index_status_histories_on_key` (`key`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `status_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `deleted_at` datetime DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `user_id` int(11) DEFAULT NULL,
  `severity` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user` (`user_id`) USING BTREE,
  KEY `index_status_messages_on_deleted_at_and_created_at` (`deleted_at`,`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `status_repository_publishes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `build_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `repository_id` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_status_repository_publishes_on_repository_id` (`repository_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `tokens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `string` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `package_id` int(11) DEFAULT NULL,
  `type` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_tokens_on_string` (`string`) USING BTREE,
  KEY `user_id` (`user_id`) USING BTREE,
  KEY `package_id` (`package_id`) USING BTREE,
  CONSTRAINT `tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `tokens_ibfk_2` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `updateinfo_counters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `maintenance_db_project_id` int(11) DEFAULT NULL,
  `day` int(11) DEFAULT NULL,
  `month` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  `counter` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `user_registrations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL DEFAULT '0',
  `token` text CHARACTER SET utf8 NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_registrations_user_id_index` (`user_id`) USING BTREE,
  KEY `user_registrations_expires_at_index` (`expires_at`) USING BTREE,
  CONSTRAINT `user_registrations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime(6) DEFAULT NULL,
  `last_logged_in_at` datetime DEFAULT NULL,
  `login_failure_count` int(11) NOT NULL DEFAULT '0',
  `login` text CHARACTER SET utf8 COLLATE utf8_bin,
  `email` varchar(200) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `realname` varchar(200) CHARACTER SET utf8 NOT NULL DEFAULT '',
  `password_digest` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `deprecated_password` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `deprecated_password_hash_type` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `deprecated_password_salt` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `adminnote` text COLLATE utf8mb4_unicode_ci,
  `state` enum('unconfirmed','confirmed','locked','deleted','subaccount') CHARACTER SET utf8 COLLATE utf8_bin DEFAULT 'unconfirmed',
  `owner_id` int(11) DEFAULT NULL,
  `ignore_auth_services` tinyint(1) DEFAULT '0',
  `in_beta` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_login_index` (`login`(255)) USING BTREE,
  KEY `users_password_index` (`deprecated_password`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE `watched_projects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL DEFAULT '0',
  `project_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `watched_projects_users_fk_1` (`user_id`) USING BTREE,
  CONSTRAINT `watched_projects_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO `schema_migrations` (version) VALUES
('1'),
('20140210114542'),
('20140213101042'),
('20140218174400'),
('20140219185200'),
('20140516182719'),
('20140624101042'),
('20140627071042'),
('20140704101043'),
('20140709071042'),
('20140714112346'),
('20140717101042'),
('20140718112346'),
('20140721112346'),
('20140729101042'),
('20140801071042'),
('20140819071042'),
('20140821105426'),
('20140827105426'),
('20140903105426'),
('20140903125426'),
('20140908125426'),
('20140908135426'),
('20140916135426'),
('20140930135426'),
('20141001135426'),
('20141002130129'),
('20141002231042'),
('20141022105426'),
('20141022205426'),
('20141107135426'),
('20141110105426'),
('20141125105426'),
('20141201135426'),
('20141202135426'),
('20141208135426'),
('20150112135426'),
('20150127135426'),
('20150129135426'),
('20150129135427'),
('20150227063641'),
('20150623063641'),
('20150625105426'),
('20150630135426'),
('20150715112346'),
('20150716112346'),
('20150716124906'),
('20150807105426'),
('20150902130939'),
('20150903084813'),
('20150916084813'),
('20151030130011'),
('20160321085300'),
('20160321104000'),
('20160321105300'),
('20160518105300'),
('20160610105300'),
('20160808135426'),
('20160819105300'),
('20160824132643'),
('20161019231042'),
('20161025231042'),
('20161115094035'),
('20161117135426'),
('20161121162349'),
('20161122121211'),
('20161122123708'),
('20161123124803'),
('20161124133941'),
('20161124135426'),
('20161128115942'),
('20170103132257'),
('20170111114943'),
('20170118091131'),
('20170123115500'),
('20170215231042'),
('20170306084558'),
('20170306105300'),
('20170315190919'),
('20170315200936'),
('20170316090223'),
('20170317094221'),
('20170320151300'),
('20170323123236'),
('20170412121601'),
('20170412121957'),
('20170413212201'),
('20170426153510'),
('20170509123922'),
('20170511120355'),
('20170516140442'),
('20170607110443'),
('20170614083014'),
('20170619111734'),
('20170621083718'),
('20170621100321'),
('20170621103748'),
('20170627111730'),
('20170628115727'),
('20170630121602'),
('20170630144825'),
('20170704125123'),
('20170704133728'),
('20170704212201'),
('20170710133627'),
('20170710134059'),
('20170821110838'),
('20170821110918'),
('20170821110941'),
('20170821110946'),
('20170905081525'),
('20170905101113'),
('20170911142301'),
('20170912140257'),
('20170912140713'),
('20170921100521'),
('20170925060940'),
('20171011125520'),
('20171013103921'),
('20171019151800'),
('20171030143054'),
('20171030150551'),
('20171102110929'),
('20171107125828'),
('20171109095756'),
('20171212083426'),
('20171218160607'),
('20171219122451'),
('20180109115548'),
('20180110074142'),
('20180216082148'),
('20180221175514'),
('20180307074538'),
('20180516074538'),
('20180523123532'),
('20180720082742'),
('20180731124926'),
('20180731125103'),
('20180807114201'),
('20180814112739');


