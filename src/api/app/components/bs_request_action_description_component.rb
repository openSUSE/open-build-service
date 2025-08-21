# This component renders the request action description based on the type of the action

class BsRequestActionDescriptionComponent < ApplicationComponent
  attr_reader :action

  delegate :project_or_package_link, to: :helpers
  delegate :user_with_realname_and_icon, to: :helpers
  delegate :requester_str, to: :helpers
  delegate :creator_intentions, to: :helpers

  def initialize(action:)
    super()
    @action = action
  end

  def source_and_target_container
    BsRequestActionSourceAndTargetComponent.new(action.bs_request).combine(source_container, target_container)
  end

  def source_container
    source_project_hash = { project: action.source_project, package: action.source_package, trim_to: nil }

    project_or_package_link(source_project_hash)
  end

  def target_container
    target_project_hash = { project: action.target_project, package: action.target_package, trim_to: nil }

    project_or_package_link(target_project_hash)
  end

  def target_repository
    target_project_hash = { project: action.target_project, package: action.target_package, trim_to: nil }

    repository_content = link_to(action.target_repository, repositories_path(target_project_hash))
    "repository #{repository_content} for " if action.target_repository
  end
end
