# frozen_string_literal: true
class SplitReviewReferences < ActiveRecord::Migration[5.1]
  def up
    # Migrate by_user reviews
    add_reference(:reviews, :user, index: true, type: :integer)
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN users ON users.login = reviews.by_user
      SET reviews.user_id = users.id
      WHERE reviews.by_user IS NOT NULL
    SQL
    execute(sql)

    # migrate by_group reviews
    add_reference(:reviews, :group, index: true, type: :integer)
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN groups ON groups.title = reviews.by_group
      SET reviews.group_id = groups.id
      WHERE reviews.by_group IS NOT NULL
    SQL
    execute(sql)

    # migrate by_project reviews
    add_reference(:reviews, :project, index: true, type: :integer)
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN projects ON projects.name = reviews.by_project
      SET reviews.project_id = projects.id
      WHERE reviews.by_project IS NOT NULL
    SQL
    execute(sql)

    # migrate by_package reviews
    add_reference(:reviews, :package, index: true, type: :integer)
    sql = <<-SQL
      UPDATE reviews
      INNER JOIN projects ON projects.name = reviews.by_project
      INNER JOIN packages ON packages.name = reviews.by_package AND packages.project_id = projects.id
      SET reviews.package_id = packages.id
      WHERE reviews.by_project IS NOT NULL AND reviews.by_package IS NOT NULL
    SQL
    execute(sql)

    remove_reference(:reviews, :reviewable, polymorphic: true)
  end

  def down
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

    remove_reference(:reviews, :user, index: true)
    remove_reference(:reviews, :group, index: true)
    remove_reference(:reviews, :project, index: true)
    remove_reference(:reviews, :package, index: true)
  end
end
