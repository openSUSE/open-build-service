# frozen_string_literal: true

class AddReferencesToBsRequestAction < ActiveRecord::Migration[5.0]
  def up
    add_reference(:bs_request_actions, :target_package, index: true)
    add_reference(:bs_request_actions, :target_project, index: true)
    add_reference(:bs_request_actions, :source_package, index: true)
    add_reference(:bs_request_actions, :source_project, index: true)

    sql = <<-SQL
      UPDATE bs_request_actions
      INNER JOIN projects ON projects.name = bs_request_actions.target_project
      SET bs_request_actions.target_project_id = projects.id
      WHERE bs_request_actions.target_project IS NOT NULL
    SQL
    execute(sql)

    sql = <<-SQL
      UPDATE bs_request_actions
      INNER JOIN projects ON projects.name = bs_request_actions.target_project
      INNER JOIN packages ON packages.name = bs_request_actions.target_package AND packages.project_id = projects.id
      SET bs_request_actions.target_package_id = packages.id
      WHERE bs_request_actions.target_project IS NOT NULL AND bs_request_actions.target_package IS NOT NULL
    SQL
    execute(sql)

    sql = <<-SQL
      UPDATE bs_request_actions
      INNER JOIN projects ON projects.name = bs_request_actions.source_project
      SET bs_request_actions.source_project_id = projects.id
      WHERE bs_request_actions.source_project IS NOT NULL
    SQL
    execute(sql)

    sql = <<-SQL
      UPDATE bs_request_actions
      INNER JOIN projects ON projects.name = bs_request_actions.source_project
      INNER JOIN packages ON packages.name = bs_request_actions.source_package AND packages.project_id = projects.id
      SET bs_request_actions.source_package_id = packages.id
      WHERE bs_request_actions.source_project IS NOT NULL AND bs_request_actions.source_package IS NOT NULL
    SQL
    execute(sql)
  end

  def down
    remove_reference(:bs_request_actions, :target_package, index: true)
    remove_reference(:bs_request_actions, :target_project, index: true)
    remove_reference(:bs_request_actions, :source_package, index: true)
    remove_reference(:bs_request_actions, :source_project, index: true)
  end
end
