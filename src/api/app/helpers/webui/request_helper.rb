module Webui::RequestHelper
  include Webui::UserHelper
  include Webui::WebuiHelper

  STATE_COLORS = {
    'new' => 'green',
    'accepted' => 'green',
    'revoked' => 'orange',
    'declined' => 'red',
    'superseded' => 'red'
  }.freeze

  STATE_BOOTSTRAP_ICONS = {
    'new' => 'fa-code-branch',
    'review' => 'fa-search',
    'accepted' => 'fa-check',
    'declined' => 'fa-hand-paper',
    'revoked' => 'fa-eraser',
    'superseded' => 'fa-plus'
  }.freeze

  AVAILABLE_TYPES = %w[all submit delete add_role change_devel maintenance_incident maintenance_release release].freeze
  AVAILABLE_STATES = ['new or review', 'new', 'review', 'accepted', 'declined', 'revoked', 'superseded'].freeze

  def request_state_color(state)
    STATE_COLORS[state.to_s] || ''
  end

  def request_bootstrap_icon(state)
    STATE_BOOTSTRAP_ICONS[state.to_s] || ''
  end

  def new_or_update_request(row)
    if row.target_package_id || row.request_type != 'submit'
      row.request_type
    else
      "#{row.request_type} <small>(new package)</small>".html_safe
    end
  end

  def merge_opt(res, opt, value)
    res[opt] ||= value
    res[opt] = :multiple if value != res[opt]
  end

  def common_parts(req)
    Rails.cache.fetch([req, 'common_parts']) do
      res = {}
      res[:source_package] = nil
      res[:source_project] = nil
      res[:target_package] = nil
      res[:target_project] = nil
      res[:request_type] = nil

      req.bs_request_actions.each do |ae|
        merge_opt(res, :source_package, ae.source_package)
        merge_opt(res, :source_project, ae.source_project)
        merge_opt(res, :target_package, ae.target_package)
        merge_opt(res, :target_project, ae.target_project)
        merge_opt(res, :request_type, ae.action_type)
        res[:target_package_id] ||= ae.target_package_id
      end

      res[:request_type] = map_request_type(res[:request_type])
      res
    end
  end

  def map_request_type(type)
    # for a simplified view on a request, must be used only for lists
    case type
    when :change_devel
      'chgdev'
    when :set_bugowner
      'bugowner'
    when :add_role
      'addrole'
    when :maintenance_incident
      'incident'
    when :maintenance_release, :release
      'release' # the difference between maintenance_release and release should matter in simplified view
    else
      type.to_s
    end
  end

  def target_project_link(row)
    result = ''
    if row.target_project
      result = if row.target_package && row.source_package != row.target_package
                 project_or_package_link(project: row.target_project, package: row.target_package, trim_to: 40, short: true)
               else
                 project_or_package_link(project: row.target_project, trim_to: 40, short: true)
               end
    end
    result
  end

  def calculate_filename(filename, file_element)
    return filename unless %w[changed renamed].include?(file_element['state'])
    return filename if file_element['old']['name'] == filename

    "#{file_element['old']['name']} -> #{filename}"
  end

  def diff_data(action_type, sourcediff)
    diff = (action_type == :delete ? sourcediff['old'] : sourcediff['new'])

    { project: diff['project'], package: diff['package'], rev: diff['rev'], expand: 1 }
  end

  def diff_label(diff)
    "#{diff['project']} / #{diff['package']} (rev #{diff['rev']})"
  end

  # [DEPRECATED] TODO: drop this helper function after request_workflow_redesign is rolled out
  # rubocop:disable Style/FormatString
  def request_action_header(action, creator)
    source_project_hash = { project: action[:sprj], package: action[:spkg], trim_to: nil }

    description = case action[:type]
                  when :submit
                    'Submit %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :delete
                    target_repository = "repository #{link_to(action[:trepo], repositories_path(project: action[:tprj], repository: action[:trepo]))} for " if action[:trepo]

                    'Delete %{target_repository}%{target_container}' % {
                      target_repository: target_repository,
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :add_role, :set_bugowner
                    '%{creator} wants %{requester} to %{task} for %{target_container}' % {
                      creator: user_with_realname_and_icon(creator),
                      requester: requester_str(creator, action[:user], action[:group]),
                      task: creator_intentions(action[:role]),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :change_devel
                    'Set the devel project to %{source_container} for %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :maintenance_incident
                    source_project_hash.update(homeproject: creator)
                    'Submit update from %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :maintenance_release
                    'Maintenance release %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  when :release
                    'Release %{source_container} to %{target_container}' % {
                      source_container: project_or_package_link(source_project_hash),
                      target_container: project_or_package_link(project: action[:tprj], package: action[:tpkg])
                    }
                  end

    description.html_safe
  end
  # rubocop:enable Style/FormatString

  def list_maintainers(maintainers)
    maintainers.pluck(:login).map do |maintainer|
      user_with_realname_and_icon(maintainer, short: true)
    end.to_sentence.html_safe
  end

  # Returns strings like "Add Role", "Submit", etc.
  def request_type_of_action(bs_request)
    return 'Multiple Actions' if bs_request.bs_request_actions.size > 1

    bs_request.bs_request_actions.first.type.titleize
  end

  def next_prev_path(**opts)
    parameters = { number: opts[:number], request_action_id: opts[:request_action_id], diff_to_superseded: opts[:diff_to_superseded] }

    case opts[:page_name]
    when 'request_build_results'
      request_build_results_path(parameters)
    when 'request_rpm_lint'
      request_rpm_lint_path(parameters)
    when 'request_changes'
      request_changes_path(parameters)
    when 'request_mentioned_issues'
      request_mentioned_issues_path(parameters)
    else
      request_show_path(parameters)
    end
  end

  private

  def action_type_icon(type)
    case type
    when 'maintenance_incident'
      'fas fa-person-digging fa-fw'
    when 'add_role'
      'fas fa-people-arrows fa-fw'
    when 'set_bugowner'
      'fas fa-bug-slash fa-fw'
    when 'delete'
      'fas fa-trash-can fa-fw'
    when 'change_devel'
      'fas fa-house-flag fa-fw'
    when 'release', 'maintenance_release'
      'fas fa-road-circle-check fa-fw'
    else
      'fas fa-code-pull-request fa-fw'
    end
  end

  # Note: We don't allow labeling requests with more than 1 target project
  def project_for_labels(bs_request)
    target_project_ids = bs_request.bs_request_actions.pluck(:target_project_id).uniq
    return if target_project_ids.count > 1

    Project.find_by(id: target_project_ids.last)
  end

  def can_apply_labels?(bs_request:, user:)
    return false if project_for_labels(bs_request).nil?

    user.admin? || bs_request.target_maintainer?(user)
  end
end
