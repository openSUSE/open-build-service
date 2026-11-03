# Renders the "what -> where" line of a request in the requests list.
#
# Multi-action requests name only a few of their actions, depending on the available width:
# actions are grouped by type, the largest group always gets a name, then the smaller groups are named first
# (so rare actions like deletes or role changes stay visible) and whatever doesn't fit is summarized as "+ N more".
class BsRequestActionsSummaryComponent < ApplicationComponent
  include RequestActionsPopover

  # CSS classes of each responsive variant and how many action names it shows
  NAME_BUDGETS = { 'd-none d-xl-inline' => 4, 'd-none d-md-inline d-xl-none' => 2, 'd-md-none' => 0 }.freeze
  TYPE_NOUNS = { 'submit' => 'package', 'delete' => 'deletion', 'add_role' => 'role change', 'set_bugowner' => 'bugowner change',
                 'change_devel' => 'devel change', 'maintenance_incident' => 'incident', 'maintenance_release' => 'release',
                 'release' => 'release' }.freeze
  VERBS = { 'maintenance_incident' => 'Maintenance incident', 'maintenance_release' => 'Maintenance release', 'release' => 'Release' }.freeze

  Group = Struct.new(:type, :actions, :named_count) do
    def size
      actions.size
    end

    def remaining
      size - named_count
    end
  end

  attr_reader :bs_request, :actions, :show_versions

  delegate :action_type_icon, to: :helpers

  def initialize(bs_request:, show_versions: false)
    super()

    @bs_request = bs_request
    @actions = bs_request.bs_request_actions.to_a
    @show_versions = show_versions
  end

  def render?
    actions.any?
  end

  def single_action
    actions.first if actions.one?
  end

  def groups(budget)
    groups = actions.group_by(&:type).map { |type, type_actions| Group.new(type, type_actions, 0) }
    remaining = budget
    if remaining.positive?
      groups.max_by(&:size).named_count = 1
      remaining -= 1
    end
    sort_by_size(groups).each do |group|
      taken = [group.remaining, remaining].min
      group.named_count += taken
      remaining -= taken
    end
    # Naming the last action takes about as much room as "+ 1 more"
    groups.each { |group| group.named_count += 1 if group.named_count.positive? && group.remaining == 1 }
    sort_by_size(groups).reverse
  end

  def action_name(action)
    return action.person_name || action.group_name if role_action?(action)

    action.source_package || action.target_package || action.source_project || action.target_project
  end

  def source_title(action)
    source = [action.source_project, action.source_package].compact.join(' / ')
    "From #{source}" if source.present?
  end

  # The target package is left out when it has the same name as the source package
  def target(action)
    return action.target_project if action.target_package.blank? || action.target_package == action.source_package

    "#{action.target_project} / #{action.target_package}"
  end

  def targets
    @targets ||= actions.map(&:target_project).compact.uniq
  end

  # "project / package" when all the actions target the same package, unless it is also the name of the source packages
  def target_package
    return @target_package if defined?(@target_package)

    pairs = actions.map { |action| [action.target_project, action.target_package] }.uniq
    project, package = pairs.first
    source_packages = actions.filter_map(&:source_package).uniq
    @target_package = ("#{project} / #{package}" if pairs.one? && project.present? && package.present? && source_packages != [package])
  end

  def role_name(action)
    action.type == 'set_bugowner' ? 'bugowner' : action.role
  end

  def role_suffix(group)
    roles = group.actions.map { |action| role_name(action) }.compact.uniq
    "as #{roles.first}" if roles.one?
  end

  def group_noun(group)
    TYPE_NOUNS.fetch(group.type, 'action').pluralize(group.size)
  end

  def group_popover(group)
    popover_data(group.actions.map { |action| "#{action_name(action)} → #{target(action)}" })
  end

  def targets_popover
    popover_data(targets)
  end

  def version_change
    return unless show_versions

    [bs_request.target_package_latest_local_version, bs_request.source_package_latest_local_version].compact.join(' → ').presence
  end

  private

  def role_action?(action)
    action.type.in?(%w[add_role set_bugowner])
  end

  # Smallest first, keeping the request's order between groups of the same size
  def sort_by_size(groups)
    groups.each_with_index.sort_by { |group, index| [group.size, -index] }.map(&:first)
  end
end
