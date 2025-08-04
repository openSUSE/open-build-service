class BsRequestActionSourceAndTargetComponent < ApplicationComponent
  attr_reader :bs_request_action, :number_of_bs_request_actions, :text_only

  delegate :project_or_package_link, to: :helpers

  def initialize(bs_request, text_only: true)
    @bs_request_action = bs_request.bs_request_actions.first
    @number_of_bs_request_actions = bs_request.bs_request_actions.size
    @text_only = text_only
  end

  def source
    if text_only
      @source ||= if number_of_bs_request_actions > 1
                    ''
                  else
                    [bs_request_action.source_project, bs_request_action.source_package].compact.join(' / ')
                  end
    else
      project_or_package_link({ project: @bs_request_action.source_project, package: @bs_request_action.source_package, trim_to: nil })
    end
  end

  def target
    if text_only
      return bs_request_action.target_project if number_of_bs_request_actions > 1

      [bs_request_action.target_project, bs_request_action.target_package].compact.join(' / ')
    else
      project_or_package_link({ project: @bs_request_action.target_project, package: @bs_request_action.target_package, trim_to: nil })
    end
  end
end
