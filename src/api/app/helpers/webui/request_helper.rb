module Webui::RequestHelper

  STATE_COLORS = {
      'new' => 'green',
      'declined' => 'red',
      'superseded' => 'red',
  }

  def request_state_color(state)
    STATE_COLORS[state.to_s] || ''
  end

  def merge_opt(res, opt, value)
    res[opt] ||= value
    if value != res[opt]
      res[opt] = :multiple
    end
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

end
