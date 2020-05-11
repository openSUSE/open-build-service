module Staging
  class ProjectDecorator < BaseDecorator
    # If the staging project has a title we use the title.
    # If the staging project has no title and is a subproject of the workflow
    # project we remove the workflow project name from the string.
    # And if the staging project has no title and is not a subproject then we
    # show the name.
    def title
      return model.title if model.title.present?

      workflow_project = model.staging_workflow.project
      model.name.delete_prefix("#{workflow_project}:")
    end
  end
end
