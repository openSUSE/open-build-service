class AddReferencesToBsRequestAction < ActiveRecord::Migration[5.0]
  def up
    start = Time.now
    add_reference(:bs_request_actions, :source, polymorphic: true)
    add_reference(:bs_request_actions, :target, polymorphic: true)

    target_projects = BsRequestAction.where("target_project IS NOT NULL AND target_package IS NULL").distinct(:target_project).pluck(:target_project)
    source_projects = BsRequestAction.where("source_project IS NOT NULL AND source_package IS NULL").distinct(:source_project).pluck(:source_project)
    tmp = (target_projects + source_projects).uniq

    tmp.in_groups_of(10000) do |array|
      Project.where(name: array).each do |project|
        execute "UPDATE bs_request_actions SET source_id = #{project.id}, source_type = 'Project' WHERE source_project = '#{project.name}' AND source_package IS NULL"
        execute "UPDATE bs_request_actions SET target_id = #{project.id}, target_type = 'Project' WHERE target_project = '#{project.name}' AND target_package IS NULL"
      end
    end

    target_packages = BsRequestAction.where("target_project IS NOT NULL AND target_package IS NOT NULL").distinct(:target_package).pluck(:target_package)
    source_packages = BsRequestAction.where("source_project IS NOT NULL AND source_package IS NOT NULL").distinct(:source_package).pluck(:source_package)
    tmp = (target_packages + source_packages).uniq
    tmp.in_groups_of(10000) do |array|
      Package.includes(:project).where(name: array).each do |package|
        execute "UPDATE bs_request_actions SET source_id = #{package.id}, source_type = 'Package' WHERE source_project = '#{package.project.name}' AND source_package = '#{package.name}'"
        execute "UPDATE bs_request_actions SET target_id = #{package.id}, target_type = 'Package' WHERE target_project = '#{package.project.name}' AND target_package = '#{package.name}'"
      end
    end
    puts "AddReferencesToBsRequestAction took #{start - Time.now}"
  end

  def down
    remove_reference(:bs_request_actions, :source, polymorphic: true)
    remove_reference(:bs_request_actions, :target, polymorphic: true)
  end
end
