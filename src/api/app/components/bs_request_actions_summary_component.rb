# Renders the "what -> where" line of a request in the requests list.
#
# Multi-action requests name only a few of their actions, depending on the available width:
# actions are grouped by type, the largest group always gets a name, then the smaller groups are named first
# (so rare actions like deletes or role changes stay visible) and whatever doesn't fit is summarized as "+ N more".
#
# This class only decides what to show; wording, markup and CSS live in the template.
class BsRequestActionsSummaryComponent < ApplicationComponent
  # How many action names each width shows, from the widest to the narrowest
  NAME_BUDGETS = { wide: 4, medium: 2, narrow: 0 }.freeze
  TYPE_NOUNS = { 'submit' => 'package', 'delete' => 'deletion', 'add_role' => 'role change', 'set_bugowner' => 'bugowner change',
                 'change_devel' => 'devel change', 'maintenance_incident' => 'incident', 'maintenance_release' => 'release',
                 'release' => 'release' }.freeze
  VERBS = { 'submit' => 'Submit', 'maintenance_incident' => 'Maintenance incident', 'maintenance_release' => 'Maintenance release',
            'release' => 'Release' }.freeze
  ROLE_TYPES = %w[add_role set_bugowner].freeze

  # Actions of the same type. The first `named_count` actions are shown by name, the rest are counted.
  # `role` is the role shared by all the actions of a role group, if any.
  Group = Struct.new(:type, :actions, :named_count, :role) do
    delegate :size, to: :actions

    def remaining
      size - named_count
    end

    def named_actions
      actions.first(named_count)
    end
  end

  # One responsive variant of a multi-action summary.
  # `verb` is set when all the actions have the same type and that type has a verb.
  Variant = Struct.new(:breakpoint, :budget, :verb, :groups) do
    def names?
      budget.positive?
    end
  end

  attr_reader :bs_request, :actions, :show_versions

  delegate :action_type_icon, :request_actions_popover_data, to: :helpers

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

  def variants
    @variants ||= NAME_BUDGETS.map { |breakpoint, budget| build_variant(breakpoint, budget) }
  end

  def action_name(action)
    return action.person_name || action.group_name if role_action?(action)

    action.source_package || action.target_package || action.source_project || action.target_project
  end

  def source_path(action)
    [action.source_project, action.source_package].compact.join(' / ').presence
  end

  # The target package is left out when it has the same name as the source package
  def target(action)
    return action.target_project if action.target_package.blank? || action.target_package == action.source_package

    target_path(action)
  end

  def target_path(action)
    [action.target_project, action.target_package].compact.join(' / ')
  end

  def role_name(action)
    action.type == 'set_bugowner' ? 'bugowner' : action.role
  end

  def noun(type)
    TYPE_NOUNS.fetch(type, 'action')
  end

  def targets
    @targets ||= actions.filter_map(&:target_project).uniq
  end

  # What the multi-action summary points to, nil when it can only show how many projects
  def target_label
    target_package || (targets.first if targets.one?)
  end

  def group_popover_items(group)
    group.actions.map { |action| "#{action_name(action)} → #{target(action)}" }
  end

  # [target version, source version], nil when there is nothing to show
  def version_change
    return unless show_versions

    versions = [bs_request.target_package_latest_local_version, bs_request.source_package_latest_local_version].compact
    versions.presence
  end

  private

  def build_variant(breakpoint, budget)
    groups = allocate(budget)
    groups.each { |group| group.role = shared_role(group) }
    verb = VERBS[groups.first.type] if budget.positive? && groups.one?
    Variant.new(breakpoint, budget, verb, groups)
  end

  def allocate(budget)
    groups = action_groups
    remaining = reserve_largest_group_name(groups, budget)
    allocate_remaining_names(groups, remaining)
    name_last_action_instead_of_more(groups)
    sort_by_size(groups).reverse
  end

  def action_groups
    actions.group_by(&:type).map { |type, type_actions| Group.new(type, type_actions, 0) }
  end

  def reserve_largest_group_name(groups, budget)
    return budget unless budget.positive?

    groups.max_by(&:size).named_count = 1
    budget - 1
  end

  def allocate_remaining_names(groups, remaining)
    sort_by_size(groups).each do |group|
      taken = [group.remaining, remaining].min
      group.named_count += taken
      remaining -= taken
    end
  end

  def name_last_action_instead_of_more(groups)
    # Naming the last action takes about as much room as "+ 1 more"
    groups.each do |group|
      group.named_count += 1 if group.named_count.positive? && group.remaining == 1
    end
  end

  def shared_role(group)
    return unless group.type.in?(ROLE_TYPES)

    roles = group.actions.filter_map { |action| role_name(action) }.uniq
    roles.first if roles.one?
  end

  # "project / package" when all the actions target the same package, unless it is also the name of the source packages
  def target_package
    return @target_package if defined?(@target_package)

    @target_package = target_package_label
  end

  def target_package_label
    pairs = actions.map { |action| [action.target_project, action.target_package] }.uniq
    return unless pairs.one?

    project, package = pairs.first
    source_packages = actions.filter_map(&:source_package).uniq
    return if project.blank? || package.blank? || source_packages == [package]

    "#{project} / #{package}"
  end

  def role_action?(action)
    action.type.in?(ROLE_TYPES)
  end

  # Smallest first, keeping the request's order between groups of the same size
  def sort_by_size(groups)
    groups.each_with_index.sort_by { |group, index| [group.size, -index] }.map(&:first)
  end
end
