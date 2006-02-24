-- [ActiveRBAC 0.1]

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_groups_groups_parent]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[groups] DROP CONSTRAINT FK_groups_groups_parent
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_groups_roles_groups]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[groups_roles] DROP CONSTRAINT FK_groups_roles_groups
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_groups_users_groups]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[groups_users] DROP CONSTRAINT FK_groups_users_groups
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_groups_roles_roles]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[groups_roles] DROP CONSTRAINT FK_groups_roles_roles
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_roles_roles_parent]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[roles] DROP CONSTRAINT FK_roles_roles_parent
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_roles_static_permissions_roles]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[roles_static_permissions] DROP CONSTRAINT FK_roles_static_permissions_roles
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_roles_users_roles]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[roles_users] DROP CONSTRAINT FK_roles_users_roles
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_roles_static_permissions_static_permissions]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[roles_static_permissions] DROP CONSTRAINT FK_roles_static_permissions_static_permissions
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_groups_users_users]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[groups_users] DROP CONSTRAINT FK_groups_users_users
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_roles_users_users]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[roles_users] DROP CONSTRAINT FK_roles_users_users
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FK_user_registrations_users]') and OBJECTPROPERTY(id, N'IsForeignKey') = 1)
ALTER TABLE [dbo].[user_registrations] DROP CONSTRAINT FK_user_registrations_users
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[groups]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[groups]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[groups_roles]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[groups_roles]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[groups_users]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[groups_users]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[roles]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[roles]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[roles_static_permissions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[roles_static_permissions]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[roles_users]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[roles_users]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[static_permissions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[static_permissions]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[user_registrations]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[user_registrations]
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[users]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[users]
GO

CREATE TABLE [dbo].[groups] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[created_at] [datetime] NOT NULL ,
	[updated_at] [datetime] NOT NULL ,
	[title] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[parent_id] [int] NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[groups_roles] (
	[group_id] [int] NOT NULL ,
	[role_id] [int] NOT NULL ,
	[created_at] [datetime] NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[groups_users] (
	[group_id] [int] NULL ,
	[user_id] [int] NULL ,
	[created_at] [datetime] NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[roles] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[created_at] [datetime] NOT NULL ,
	[updated_at] [datetime] NOT NULL ,
	[title] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[parent_id] [int] NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[roles_static_permissions] (
	[static_permission_id] [int] NOT NULL ,
	[role_id] [int] NOT NULL ,
	[created_at] [datetime] NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[roles_users] (
	[user_id] [int] NOT NULL ,
	[role_id] [int] NOT NULL ,
	[created_at] [datetime] NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[static_permissions] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[title] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[created_at] [datetime] NOT NULL ,
	[updated_at] [datetime] NOT NULL 
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[user_registrations] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[user_id] [int] NOT NULL ,
	[token] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[created_at] [datetime] NOT NULL ,
	[expires_at] [datetime] NOT NULL 
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[users] (
	[id] [int] IDENTITY (1, 1) NOT NULL ,
	[created_at] [datetime] NOT NULL ,
	[updated_at] [datetime] NOT NULL ,
	[last_logged_in_at] [datetime] NOT NULL ,
	[login_failure_count] [int] NOT NULL ,
	[login] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[email] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[password] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[password_hash_type] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[password_salt] [char] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[state] [int] NOT NULL 
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[groups] WITH NOCHECK ADD 
	CONSTRAINT [PK_groups] PRIMARY KEY  CLUSTERED 
	(
		[id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[roles] WITH NOCHECK ADD 
	CONSTRAINT [PK_roles] PRIMARY KEY  CLUSTERED 
	(
		[id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[static_permissions] WITH NOCHECK ADD 
	CONSTRAINT [PK_static_permissions] PRIMARY KEY  CLUSTERED 
	(
		[id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[user_registrations] WITH NOCHECK ADD 
	CONSTRAINT [PK_user_registrations] PRIMARY KEY  CLUSTERED 
	(
		[id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[users] WITH NOCHECK ADD 
	CONSTRAINT [PK_users] PRIMARY KEY  CLUSTERED 
	(
		[id]
	)  ON [PRIMARY] 
GO

ALTER TABLE [dbo].[groups] ADD 
	CONSTRAINT [UC_groups_title] UNIQUE  NONCLUSTERED 
	(
		[title]
	)  ON [PRIMARY] 
GO

 CREATE  INDEX [IX_groups_parent_id] ON [dbo].[groups]([parent_id]) ON [PRIMARY]
GO

 CREATE  UNIQUE  INDEX [IX_groups_roles_all] ON [dbo].[groups_roles]([group_id], [role_id]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_groups_users_all] ON [dbo].[groups_users]([group_id], [user_id]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[roles] ADD 
	CONSTRAINT [UC_roles_title] UNIQUE  NONCLUSTERED 
	(
		[title]
	)  ON [PRIMARY] 
GO

 CREATE  INDEX [IX_roles_parent_id] ON [dbo].[roles]([parent_id]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[roles_static_permissions] ADD 
	CONSTRAINT [UC_roles_static_permissions_roles] UNIQUE  NONCLUSTERED 
	(
		[static_permission_id],
		[role_id]
	)  ON [PRIMARY] 
GO

 CREATE  UNIQUE  INDEX [IX_roles_static_permissions_roles] ON [dbo].[roles_static_permissions]([static_permission_id], [role_id]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_roles_static_permissions] ON [dbo].[roles_static_permissions]([static_permission_id]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[roles_users] ADD 
	CONSTRAINT [UC_roles_users] UNIQUE  NONCLUSTERED 
	(
		[user_id],
		[role_id]
	)  ON [PRIMARY] 
GO

 CREATE  INDEX [IX_roles_users_all] ON [dbo].[roles_users]([user_id], [role_id]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[static_permissions] ADD 
	CONSTRAINT [UC_static_permissions_title] UNIQUE  NONCLUSTERED 
	(
		[title]
	)  ON [PRIMARY] 
GO

 CREATE  UNIQUE  INDEX [IX_static_permissions_title] ON [dbo].[static_permissions]([title]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[user_registrations] ADD 
	CONSTRAINT [UC_user_registrations_user_id] UNIQUE  NONCLUSTERED 
	(
		[user_id]
	)  ON [PRIMARY] 
GO

 CREATE  INDEX [IX_user_registrations_user_id] ON [dbo].[user_registrations]([user_id]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_user_registrations_expires_at] ON [dbo].[user_registrations]([expires_at]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[users] ADD 
	CONSTRAINT [DF_users_login_failure_count] DEFAULT (0) FOR [login_failure_count],
	CONSTRAINT [DF_users_state] DEFAULT (1) FOR [state],
	CONSTRAINT [UC_users_login] UNIQUE  NONCLUSTERED 
	(
		[login]
	)  ON [PRIMARY] 
GO

 CREATE  INDEX [IX_users_login] ON [dbo].[users]([login]) ON [PRIMARY]
GO

 CREATE  INDEX [IX_users_password] ON [dbo].[users]([password]) ON [PRIMARY]
GO

ALTER TABLE [dbo].[groups] ADD 
	CONSTRAINT [FK_groups_groups_parent] FOREIGN KEY 
	(
		[parent_id]
	) REFERENCES [dbo].[groups] (
		[id]
	)
GO

ALTER TABLE [dbo].[groups_roles] ADD 
	CONSTRAINT [FK_groups_roles_groups] FOREIGN KEY 
	(
		[group_id]
	) REFERENCES [dbo].[groups] (
		[id]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_groups_roles_roles] FOREIGN KEY 
	(
		[role_id]
	) REFERENCES [dbo].[roles] (
		[id]
	) ON DELETE CASCADE 
GO

ALTER TABLE [dbo].[groups_users] ADD 
	CONSTRAINT [FK_groups_users_groups] FOREIGN KEY 
	(
		[group_id]
	) REFERENCES [dbo].[groups] (
		[id]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_groups_users_users] FOREIGN KEY 
	(
		[user_id]
	) REFERENCES [dbo].[users] (
		[id]
	) ON DELETE CASCADE 
GO

ALTER TABLE [dbo].[roles] ADD 
	CONSTRAINT [FK_roles_roles_parent] FOREIGN KEY 
	(
		[parent_id]
	) REFERENCES [dbo].[roles] (
		[id]
	) NOT FOR REPLICATION 
GO

alter table [dbo].[roles] nocheck constraint [FK_roles_roles_parent]
GO

ALTER TABLE [dbo].[roles_static_permissions] ADD 
	CONSTRAINT [FK_roles_static_permissions_roles] FOREIGN KEY 
	(
		[role_id]
	) REFERENCES [dbo].[roles] (
		[id]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_roles_static_permissions_static_permissions] FOREIGN KEY 
	(
		[static_permission_id]
	) REFERENCES [dbo].[static_permissions] (
		[id]
	) ON DELETE CASCADE 
GO

ALTER TABLE [dbo].[roles_users] ADD 
	CONSTRAINT [FK_roles_users_roles] FOREIGN KEY 
	(
		[role_id]
	) REFERENCES [dbo].[roles] (
		[id]
	) ON DELETE CASCADE ,
	CONSTRAINT [FK_roles_users_users] FOREIGN KEY 
	(
		[user_id]
	) REFERENCES [dbo].[users] (
		[id]
	) ON DELETE CASCADE 
GO

ALTER TABLE [dbo].[user_registrations] ADD 
	CONSTRAINT [FK_user_registrations_users] FOREIGN KEY 
	(
		[user_id]
	) REFERENCES [dbo].[users] (
		[id]
	) ON DELETE CASCADE  ON UPDATE CASCADE 
GO

