module Webui::RequestHelper

  STATE_ICONS = {
      'new' => 'flag_green',
      'review' => 'flag_yellow',
      'declined' => 'flag_red',
  }

  def map_request_state_to_flag(state)
    STATE_ICONS[state.to_s] || ''
  end

  STATE_COLORS = {
      'new' => 'green',
      'declined' => 'red',
      'superseded' => 'red',
  }

  def request_state_color(state)
    STATE_COLORS[state.to_s] || ''
  end

  def find_common_part(req)
    part = nil
    req.bs_request_actions.each do |ae|
      field = yield ae
      part ||= field
      if field != part
        return :multiple
      end
    end
    part
  end

  def source_package_for_request(req)
    find_common_part(req) do |ae|
      ae.source_package
    end
  end

  def source_project_for_request(req)
    find_common_part(req) do |ae|
      ae.source_project
    end
  end

  def request_type_for_request(req)
    # for a simplified view on a request, must be used only for lists
    type = find_common_part(req) { |ae| ae.action_type }
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

  def target_package_for_request(req)
    find_common_part(req) do |ae|
      ae.target_package
    end
  end

  def target_project_for_request(req)
    find_common_part(req) do |ae|
      ae.target_project
    end
  end
end
