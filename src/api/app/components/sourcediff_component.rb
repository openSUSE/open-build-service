class SourcediffComponent < ApplicationComponent
  attr_accessor :bs_request, :action, :index, :refresh

  delegate :diff_label, to: :helpers
  delegate :diff_data, to: :helpers

  def initialize(bs_request:, action:, index:)
    super

    @bs_request = bs_request
    @action = action
    @index = index
  end

  def commentable
    BsRequestAction.find(@action[:id])
  end

  def source_package
    Package.get_by_project_and_name(@action[:sprj], @action[:spkg], { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
  end

  def target_package
    # For not accepted maintenance incident requests, the package is not there.
    return nil unless @action[:tpkg]

    Package.get_by_project_and_name(@action[:tprj], @action[:tpkg], { follow_multibuild: true })
  rescue Package::UnknownObjectError, Project::Errors::UnknownObjectError
  end
end
