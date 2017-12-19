class ProjectCreateAutoCleanupRequests < ApplicationJob
  DESCRIPTION = "This is a humble request to remove this project.
Accepting this request will free resources on our always crowded server.
Please decline this request if you want to keep this repository nevertheless. Otherwise this request
will get accepted automatically in near future.
Such requests get not created for projects with open requests or if you remove the OBS:AutoCleanup attribute.".freeze

  def perform
    # disabled ?
    cleanup_days = ::Configuration.cleanup_after_days
    return unless cleanup_days && cleanup_days > 0

    # defaults
    User.current ||= User.find_by_login 'Admin'
    @cleanup_attribute = AttribType.find_by_namespace_and_name!('OBS', 'AutoCleanup')
    @cleanup_time = DateTime.now + cleanup_days.days

    Project.find_by_attribute_type(@cleanup_attribute).each do |prj|
      autoclean_project(prj)
    end
  end

  def autoclean_project(prj)
    # project may be locked?
    return if prj.nil? || prj.is_locked?

    # open requests do block the cleanup
    open_requests_count = BsRequest.in_states([:new, :review, :declined]).
      joins(:bs_request_actions).
      where('bs_request_actions.target_project = ? OR bs_request_actions.source_project = ?', prj.name, prj.name).
      count
    return if open_requests_count > 0

    # check the time in project attribute
    time = nil
    begin
      attribute = prj.attribs.find_by_attrib_type_id(@cleanup_attribute.id)
      return unless attribute
      time = DateTime.parse(attribute.values.first.value)
      return unless time
    rescue ArgumentError
      # not parseable time
      return
    end
    # not yet
    return unless time.past?

    # create request, but add some time between to avoid an overload
    @cleanup_time += 5.minutes

    req = BsRequest.new_from_xml('<request>
                                       <action type="delete">
                                          <target project="' + prj.name + '" />
                                       </action>
                                       <description>' + DESCRIPTION + '</description>
                                       <state />
                                       <accept_at>' + @cleanup_time.to_s + '</accept_at>
                                     </request>')
    req.save!
    Event::RequestCreate.create(req.notify_parameters)
  end
end
