desc('Insert source_project_id and source_package_id in bs_request_actions')
task(backfill_source: :environment) do
  bs_request_actions = BsRequestAction.where(source_project_id: nil, source_package_id: nil).where('source_project IS NOT NULL OR source_package IS NOT NULL')
  bs_request_actions.find_each do |action|
    source_package = Package.find_by_project_and_name(action.source_project, action.source_package)
    # Find the project directly through string because some actions won't have source_package
    source_project = Project.find_by_name(action.source_project)
    if source_package
      action.update(source_project_id: source_project.id, source_package_id: source_package.id)
    elsif source_project
      action.update(source_project_id: source_project.id)
    end
  end
end

desc('Remove target_project_id and target_package_id from bs_request_actions if the projects and packages no longer exist')
task(remove_target: :environment) do
  bs_request_actions = BsRequestAction.where('target_project_id IS NOT NULL OR target_package_id IS NOT NULL')
  bs_request_actions.find_each do |action|
    target_package = Package.find_by_project_and_name(action.target_project, action.target_package)
    target_project = target_package.try(:project)
    if target_project.nil?
      action.update(target_package_id: nil, target_project_id: nil)
    elsif target_package.nil?
      action.update(target_package_id: nil)
    end
  end
end
