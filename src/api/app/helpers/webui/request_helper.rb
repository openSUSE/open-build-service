module Webui::RequestHelper
  STATE_COLORS = {
    'new'        => 'green',
    'accepted'   => 'green',
    'revoked'    => 'orange',
    'declined'   => 'red',
    'superseded' => 'red'
  }.freeze

  def request_state_color(state)
    STATE_COLORS[state.to_s] || ''
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
    when :change_devel then
      'chgdev'
    when :set_bugowner then
      'bugowner'
    when :add_role then
      'addrole'
    when :maintenance_incident then
      'incident'
    when :maintenance_release then
      'release'
    else
      type.to_s
    end
  end

  def priority_description(prio)
    case prio
    when 'low' then
      'Work on this request if nothing else needs to be done.'
    when 'moderate' then
      'Work on this request.'
    when 'important' then
      'Finish other requests you have begun, then work on this request.'
    when 'critical' then
      'Drop everything and work on this request.'
    end
  end

  def priority_number(prio)
    case prio
    when 'low' then
      '1'
    when 'moderate' then
      '2'
    when 'important' then
      '3'
    when 'critical' then
      '4'
    end
  end

  def target_project_link(row)
    result = ''
    if row.target_project
      if row.target_package && row.source_package != row.target_package
        result = project_or_package_link(project: row.target_project, package: row.target_package, trim_to: 40, short: true)
      else
        result = project_or_package_link(project: row.target_project, trim_to: 40, short: true)
      end
    end
    result
  end

  def calculate_filename(filename, file_element)
    return filename unless file_element['state'] == 'changed'
    return filename if file_element['old']['name'] == filename
    return "#{file_element['old']['name']} -> #{filename}"
  end

  def reviewer(review)
    return "#{review[:by_project]} / #{review[:by_package]}" if review[:by_package]
    review[:by_user] || review[:by_group] || review[:by_project]
  end
end
