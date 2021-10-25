class StagingProjectLinkComponent < ApplicationComponent
  def initialize(staging_project:, staging_workflow:, link_options: {})
    super

    @staging_project = staging_project
    @staging_workflow = staging_workflow
    @link_options = link_options
  end

  def title
    return @staging_project.title if @staging_project.title.present?

    # If the staging project has no title and is a subproject of the workflow
    # project we remove the workflow project name from the string.
    # And if the staging project has no title and is not a subproject then we
    # show the name.
    workflow_project = @staging_project.staging_workflow.project
    @staging_project.name.delete_prefix("#{workflow_project}:")
  end
end
