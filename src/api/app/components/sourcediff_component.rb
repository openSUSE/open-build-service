class SourcediffComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :refresh

  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, diff_to_superseded_id:)
    super

    @bs_request = bs_request
    @action = action
    @diff_to_superseded_id = diff_to_superseded_id
  end

  def commentable
    BsRequestAction.find(@action.id)
  end

  def source_package
    Package.get_by_project_and_name(@action.source_project, @action.source_package, { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
  end

  def target_package
    # For not accepted maintenance incident requests, the package is not there.
    return nil unless @action.target_package

    Package.get_by_project_and_name(@action.target_project, @action.target_package, { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
  end
end
