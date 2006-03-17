DROP DATABASE frontend_development;
CREATE DATABASE frontend_development;
USE frontend_development;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
CREATE TABLE `groups` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `title` varchar(200) NOT NULL default '',
  `parent_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `groups_parent_id_index` (`parent_id`),
  CONSTRAINT `groups_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `groups` (`id`) ON UPDATE NO ACTION
) ENGINE=InnoDB;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
CREATE TABLE `roles` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `title` varchar(100) NOT NULL default '',
  `parent_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`id`),
  KEY `roles_parent_id_index` (`parent_id`),
  CONSTRAINT `roles_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `roles` (`id`) ON UPDATE NO ACTION
) ENGINE=InnoDB;

LOCK TABLES `roles` WRITE;
INSERT INTO `roles` VALUES 
     (1, now(), now(), 'Admin',NULL),
     (2, now(), now(), 'User',NULL);
UNLOCK TABLES;
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;


--
-- Table structure for table `groups_roles`
--

DROP TABLE IF EXISTS `groups_roles`;
CREATE TABLE `groups_roles` (
  `group_id` int(10) unsigned NOT NULL default '0',
  `role_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `groups_roles_all_index` (`group_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `groups_roles_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `groups_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;


--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `last_logged_in_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `login_failure_count` int(10) unsigned NOT NULL default '0',
  `login` varchar(100) NOT NULL default '',
  `email` varchar(200) NOT NULL default '',
  `realname` varchar(200) NOT NULL default '',
  `password` varchar(100) NOT NULL default '',
  `password_hash_type` varchar(20) NOT NULL default '',
  `password_salt` varchar(10) NOT NULL default '1234512345',
  `password_crypted` varchar(64),
  `state` int(10) unsigned NOT NULL default '1',
  `source_host` varchar(40) default NULL,
  `source_port` int(11) default NULL,
  `rpm_host` varchar(40) default NULL,
  `rpm_port` int(11) default NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `users_login_index` (`login`),
  KEY `users_password_index` (`password`)
) ENGINE=InnoDB;


DROP TABLE IF EXISTS `watched_projects`;
CREATE TABLE `watched_projects` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `bs_user_id` int(10) unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `watched_projects_users_fk_1` FOREIGN KEY (`bs_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;

--
-- Table structure for table `groups_users`
--

DROP TABLE IF EXISTS `groups_users`;
CREATE TABLE `groups_users` (
  `group_id` int(10) unsigned NOT NULL default '0',
  `user_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`group_id`,`user_id`),
  UNIQUE KEY `groups_users_all_index` (`group_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `groups_users_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `groups_users_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;


--
-- Table structure for table `static_permissions`
--

DROP TABLE IF EXISTS `static_permissions`;
CREATE TABLE `static_permissions` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `title` varchar(200) NOT NULL default '',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  `updated_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `static_permissions_title_index` (`title`)
) ENGINE=InnoDB;

LOCK TABLES `static_permissions` WRITE;
INSERT INTO `static_permissions` VALUES (1,'global_project_change', NOW(), NOW() ),
                                        (2,'global_project_create', NOW(), NOW() ),
					(3,'global_package_change', NOW(), NOW() ),
					(4,'global_package_create',  NOW(), NOW() );

UNLOCK TABLES;

--
-- Table structure for table `roles_static_permissions`
--

DROP TABLE IF EXISTS `roles_static_permissions`;
CREATE TABLE `roles_static_permissions` (
  `role_id` int(10) unsigned NOT NULL default '0',
  `static_permission_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `roles_static_permissions_all_index` (`static_permission_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `roles_static_permissions_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT `roles_static_permissions_ibfk_2` FOREIGN KEY (`static_permission_id`) REFERENCES `static_permissions` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;

LOCK TABLES `roles_static_permissions` WRITE;
INSERT INTO `roles_static_permissions` VALUES (1,1,NOW()),(1,2,NOW()),(1,3,NOW()),(1,4,NOW()), (2,2,NOW()) ;
UNLOCK TABLES;


--
-- Table structure for table `roles_users`
--

DROP TABLE IF EXISTS `roles_users`;
CREATE TABLE `roles_users` (
  `user_id` int(10) unsigned NOT NULL default '0',
  `role_id` int(10) unsigned NOT NULL default '0',
  `created_at` timestamp NOT NULL default '0000-00-00 00:00:00',
  UNIQUE KEY `roles_users_all_index` (`user_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `roles_users_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION
) ENGINE=InnoDB;

LOCK TABLES `roles_users` WRITE;
INSERT INTO `roles_users` VALUES (1,1,NOW());
UNLOCK TABLES;

--
-- Table structure for table `schema_info`
--

DROP TABLE IF EXISTS `schema_info`;
CREATE TABLE `schema_info` (
  `version` int(11) default NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `static_permissions`
--


DROP TABLE IF EXISTS `user_registrations`;
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
) ENGINE=InnoDB;


--
-- Dumping data for table `users`
--

/* Create an Admin user. */;
LOCK TABLES `users` WRITE;
INSERT INTO `users` (id, created_at, login, email, password, password_hash_type, password_salt, password_crypted, state) 
VALUES (1, now(), 'Admin','root@localhost','07a703993d4b21cabb8c698b30a63616','md5','6+DYjxVSct', '8f//Vir3vAC9s', 2);
UNLOCK TABLES;



