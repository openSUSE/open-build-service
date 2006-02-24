# [ActiveRBAC 0.1]

# This is database creation SQL script in MySQL dialect.

#----------------------------
# Table structure for groups
#----------------------------
CREATE TABLE `groups` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `title` varchar(200) NOT NULL default '',
  `parent_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `groups_parent_id_index` (`parent_id`),
  CONSTRAINT `groups_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `groups` (`id`) ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for roles
#----------------------------
CREATE TABLE `roles` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `title` varchar(100) NOT NULL default '',
  `parent_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `roles_parent_id_index` (`parent_id`),
  CONSTRAINT `roles_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `roles` (`id`) ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for static_permissions
#----------------------------
CREATE TABLE `static_permissions` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `title` varchar(200) NOT NULL default '',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `static_permissions_title_index` (`title`)
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for users
#----------------------------
CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `last_logged_in_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `login_failure_count` int(10) unsigned NOT NULL default '0',
  `login` varchar(100) NOT NULL default '',
  `email` varchar(200) NOT NULL default '',
  `password` varchar(100) NOT NULL default '',
  `password_hash_type` varchar(20) NOT NULL default '',
  `password_salt` char(10) NOT NULL default '1234512345',
  `state` int(10) unsigned NOT NULL default '1',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `users_login_index` (`login`),
  KEY `users_password_index` (`password`)
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for groups_roles
#----------------------------
CREATE TABLE `groups_roles` (
  `group_id` int(10) unsigned NOT NULL default '0',
  `role_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `groups_roles_all_index` (`group_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `groups_roles_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `groups_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for groups_users
#----------------------------
CREATE TABLE `groups_users` (
  `group_id` int(10) unsigned NOT NULL default '0',
  `user_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`group_id`,`user_id`),
  UNIQUE KEY `groups_users_all_index` (`group_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `groups_users_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `groups_users_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for roles_static_permissions
#----------------------------
CREATE TABLE `roles_static_permissions` (
  `role_id` int(10) unsigned NOT NULL default '0',
  `static_permission_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `roles_static_permissions_all_index` (`static_permission_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `roles_static_permissions_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `roles_static_permissions_ibfk_2` FOREIGN KEY (`static_permission_id`) REFERENCES `static_permissions` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for roles_users
#----------------------------
CREATE TABLE `roles_users` (
  `user_id` int(10) unsigned NOT NULL default '0',
  `role_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `roles_users_all_index` (`user_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `roles_users_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;

#----------------------------
# Table structure for user_registrations
#----------------------------
CREATE TABLE `user_registrations` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `user_id` int(10) unsigned NOT NULL default '0',
  `token` text NOT NULL,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `expires_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `user_registrations_user_id_index` (`user_id`),
  KEY `user_registrations_expires_at_index` (`expires_at`),
  CONSTRAINT `user_registrations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB CHARACTER SET utf8;