require 'opensuse/backend'

class ProjectCreateAutoCleanupRequests

  Description="This is a kind request to remove this project.
Accepting this request will free resources on our always crowded server.
Please decline this request if you want to keep this repository nevertheless. Otherwise this request
will get accepted automatically in near future.
Such requests get not created for projects with open requests or if you remove the OBS:AutoCleanup attribute."

  def initialize
  end

  def perform
    # disabled ?
    cleanupDays = ::Configuration.first.cleanup_after_days
    return unless cleanupDays and cleanupDays > 0

    # defaults
    User.current ||= User.find_by_login "Admin"
    @cleanup_attribute = AttribType.find_by_namespace_and_name("OBS", "AutoCleanup")
    @cleanupTime = DateTime.now + cleanupDays.days

    Project.find_by_attribute_type(@cleanup_attribute).each do |prj|
      autoclean_project(prj)
    end
  end

  def autoclean_project(prj)
    # project may be locked?
    return if prj.nil? or prj.is_locked?

    # open requests do block the cleanup
    return if BsRequest.open_requests_for(prj).length > 0

    # check the time in project attribute
    time = nil
    begin
      return unless attribute = prj.attribs.find_by_attrib_type_id(@cleanup_attribute.id)
      return unless time = DateTime.parse(attribute.values.first.value)
    rescue ArgumentError
      # not parseable time
      return
    end
    # not yet
    return unless time.past?

    # create request, but add some time between to avoid an overload
    @cleanupTime = @cleanupTime + 5.minutes

    req = BsRequest.new_from_xml('<request>
                                       <action type="delete">
                                          <target project="' + prj.name + '" />
                                       </action>
                                       <description>'+Description+'</description>
                                       <state who="Admin" name="new"/>
                                       <accept_at>' + @cleanupTime.to_s + '</accept_at>
                                     </request>')
    req.save!
    notify = req.notify_parameters
    Event::RequestCreate.create notify
  end

end

