class BsRequestActionTabVisibility
  CHANGES_TABS = %w[submit maintenance_incident maintenance_release].freeze

  def initialize(bs_request_action)
    @actions = bs_request_action.bs_request.bs_request_actions
  end

  def build
    @actions.any? { |a| a.type.in?(CHANGES_TABS) && a.source_project && a.source_package }
  end

  def issues
    @actions.any? { |a| a.type.in?(CHANGES_TABS) }
  end
end
