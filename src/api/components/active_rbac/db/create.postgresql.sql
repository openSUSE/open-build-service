-- [ActiveRBAC 0.1]

-- This is the database creation SQL script in PostgreSQL dialect. It 
-- has been tested with PostgreSQL 7.4.

CREATE TABLE users (
  id BIGSERIAL NOT NULL,
  -- Some statistics about the user data
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  last_logged_in_at TIMESTAMP NOT NULL,
  login_failure_count INT NOT NULL,
  -- Important information: login name, email and encrypted password
  login CHARACTER VARYING (100) NOT NULL,
  email CHARACTER VARYING (200) NOT NULL,
  password CHARACTER VARYING (100) NOT NULL,
  -- What hashing method did we use to hash the password? SHA-1, MD5, etc.?
  password_hash_type CHARACTER VARYING (20) NOT NULL,
  -- The salt used for this password
  password_salt CHARACTER (10) NOT NULL,

  -- The account's state. The stock types are "1: unconfirmed", "2: confirmed"
  -- "3: locked", "4: deleted", "4: confirmed, lost password"
  state INTEGER NOT NULL DEFAULT 1,

  PRIMARY KEY (id),
  UNIQUE (login)
);

CREATE INDEX users_login_index ON users (login);
CREATE INDEX users_password_index ON users (password);


-- This table holds the "user registration" data, i.e. the token the
-- user needs to know to confirm his registration.
CREATE TABLE user_registrations (
  id BIGSERIAL NOT NULL, -- superflous, but AR needs it
  user_id BIGINT NOT NULL,
  token TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  expires_at TIMESTAMP NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  UNIQUE (user_id)
);

CREATE INDEX user_registrations_user_id_index ON user_registrations (user_id);
CREATE INDEX user_registration_expires_at_index ON user_registrations (expires_at);


CREATE TABLE roles (
  id BIGSERIAL NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  title CHARACTER VARYING (100) NOT NULL,
  parent_id BIGINT NULL,

  PRIMARY KEY (id),
  UNIQUE(title),
  FOREIGN KEY (parent_id) REFERENCES roles (id) ON DELETE RESTRICT
);

CREATE INDEX roles_parent_index ON roles (parent_id);


CREATE TABLE roles_users (
  user_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,

  UNIQUE (user_id, role_id)
);

CREATE INDEX roles_users_all_index ON roles_users (user_id, role_id);


CREATE TABLE groups (
  id BIGSERIAL NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  title CHARACTER VARYING NOT NULL,
  parent_id BIGINT NULL,

  PRIMARY KEY (id),
  UNIQUE (title),
  FOREIGN KEY (parent_id) REFERENCES groups (id) ON DELETE RESTRICT
);

CREATE INDEX groups_parent_index ON groups (parent_id);

CREATE TABLE groups_users (
  group_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL,

  FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,

  UNIQUE (group_id, user_id)
);

CREATE INDEX groups_users_all_index ON groups_users (group_id, user_id);


CREATE TABLE groups_roles (
  group_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL,

  FOREIGN KEY (group_id) REFERENCES groups (id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,

  UNIQUE (group_id, role_id)
);

CREATE INDEX groups_roles_all_index ON groups_roles (group_id, role_id);


CREATE TABLE static_permissions (
  id BIGSERIAL NOT NULL,
  title VARCHAR(200) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  PRIMARY KEY (id),
  UNIQUE (title)
);

CREATE INDEX static_permissions_title_index ON static_permissions (title);


CREATE TABLE roles_static_permissions (
  static_permission_id BIGINT NOT NULL,
  role_id BIGINT NOT NULL,
  created_at TIMESTAMP NOT NULL,

  FOREIGN KEY (static_permission_id) REFERENCES static_permissions (id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,

  UNIQUE (static_permission_id, role_id)
);

CREATE INDEX roles_static_permissions_all_index ON roles_static_permissions (static_permission_id, role_id);