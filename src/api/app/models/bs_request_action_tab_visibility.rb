class BsRequestActionTabVisibility
  CHANGES_TABS = [:submit, :maintenance_incident, :maintenance_release].freeze

  def initialize(bs_request_action)
    @action = bs_request_action
  end

  # Handle tabs visibility
  def visible(tab_name)
    case tab_name
    when :build_results, :rpm_lint
      source_package && !patchinfo_package
    when :changes
      (@action.type == :delete && @action.source_package) || @action.type.in?(CHANGES_TABS)
    when :mentioned_issues
      @action.type.in?(CHANGES_TABS)
    else
      true
    end
  end

  private

  def patchinfo_package
    @action.type.in?([:maintenance_incident, :maintenance_release]) && @action.source_package == 'patchinfo'
  end

  def source_package
    @action.source_project && @action.source_package
  end
end
