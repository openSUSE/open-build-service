# frozen_string_literal: true

class AddReferencesToReview < ActiveRecord::Migration[5.0]
  def up
    # COLLATE for by_user, by_group, by_package and by_project was utf8_unicode_ci which made it impossible to perform a JOIN on these fields
    # Furthermore on build.opensuse.org the COLLATE was already changed to utf8_general_ci manually in the past
    execute('ALTER TABLE reviews MODIFY by_user VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci;')
    execute('ALTER TABLE reviews MODIFY by_group VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci;')
    execute('ALTER TABLE reviews MODIFY by_project VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci;')
    execute('ALTER TABLE reviews MODIFY by_package VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci;')

    add_reference(:reviews, :reviewable, polymorphic: true)

    # Migrate by_user reviews
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN users ON users.login = reviews.by_user
      SET reviews.reviewable_id = users.id, reviews.reviewable_type = 'User'
      WHERE reviews.by_user IS NOT NULL
    SQL
    execute(sql)

    # migrate by_group reviews
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN groups ON groups.title = reviews.by_group
      SET reviews.reviewable_id = groups.id, reviews.reviewable_type = 'Group'
      WHERE reviews.by_group IS NOT NULL
    SQL
    execute(sql)

    # migrate by_project reviews
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN projects ON projects.name = reviews.by_project
      SET reviews.reviewable_id = projects.id, reviews.reviewable_type = 'Project'
      WHERE reviews.by_project IS NOT NULL AND reviews.by_package IS NULL
    SQL
    execute(sql)

    # migrate by_package reviews
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN projects ON projects.name = reviews.by_project
      INNER JOIN packages ON packages.name = reviews.by_package AND packages.project_id = projects.id
      SET reviews.reviewable_id = packages.id, reviews.reviewable_type = 'Package'
      WHERE reviews.by_project IS NOT NULL AND reviews.by_package IS NOT NULL
    SQL
    execute(sql)
  end

  def down
    remove_reference(:reviews, :reviewable, polymorphic: true)
    execute('ALTER TABLE reviews MODIFY by_user VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci;')
    execute('ALTER TABLE reviews MODIFY by_group VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci;')
    execute('ALTER TABLE reviews MODIFY by_project VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci;')
    execute('ALTER TABLE reviews MODIFY by_package VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci;')
  end
end
