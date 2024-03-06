class BsRequestActionTabVisibility
  CHANGES_TABS = %w[submit maintenance_incident maintenance_release].freeze

  def initialize(bs_request_action)
    @action = bs_request_action
  end

  def build
    source_package && !patchinfo_package
  end

  def rpm_lint
    build
  end

  def changes
    (@action.type == :delete && @action.source_package) || @action.type.in?(CHANGES_TABS)
  end

  def issues
    @action.type.in?(CHANGES_TABS)
  end

  private

  def patchinfo_package
    @action.type.in?(%i[maintenance_incident maintenance_release]) && @action.source_package == 'patchinfo'
  end

  def source_package
    @action.source_project && @action.source_package
  end
end
