class BsRequestActionSourceAndTargetComponent < ApplicationComponent
  attr_reader :bs_request_action, :number_of_bs_request_actions

  def initialize(bs_request)
    super

    @bs_request_action = bs_request.bs_request_actions.first
    @number_of_bs_request_actions = bs_request.bs_request_actions.size
  end

  def call
    combine(source, target)
  end

  def source
    @source ||= if number_of_bs_request_actions > 1
                  ''
                else
                  [bs_request_action.source_project, bs_request_action.source_package].compact.join(' / ')
                end
  end

  def target
    return bs_request_action.target_project if number_of_bs_request_actions > 1

    [bs_request_action.target_project, bs_request_action.target_package].compact.join(' / ')
  end

  def combine(source, target)
    capture do
      if source.present?
        concat(tag.span(source))
        concat(tag.i(nil, class: 'fas fa-long-arrow-alt-right text-info mx-2'))
      end
      concat(tag.span(target))
    end
  end
end
