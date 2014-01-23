class ProjectCreateAutoCleanupRequests

  Description="This is a kind request to remove this project.
Accepting this request will free resources on our always crowded server.
Please decline this request if you want to keep this repository nevertheless. Otherwise this request
will get accepted automatically in near future.
Such requests get not created for projects with open requests or if you remove the OBS:AutoCleanup attribute."

  def initialize
  end

  def perform
    require 'opensuse/backend'
    # disabled ?
    cleanupDays = ::Configuration.first.cleanup_after_days
    return unless cleanupDays and cleanupDays > 0

    # defaults
    User.current ||= User.find_by_login "Admin"
    at = AttribType.find_by_namespace_and_name("OBS", "AutoCleanup")
    cleanupTime = DateTime.now + cleanupDays.days

    Project.find_by_attribute_type( at ).each do |prj|
      # project may be locked?
      next if prj.nil? or prj.is_locked?

      # open requests do block the cleanup
      next if BsRequest.open_requests_for(prj).length > 0

      # check the time in project attribute
      time = nil
      begin
        next unless attribute = prj.attribs.find_by_attrib_type_id( at.id )
        next unless time = DateTime.parse(attribute.values.first.value)
      rescue
        # not parseable time
        next
      end
      # not yet 
      next unless time.past?

      # create request, but add some time between to avoid an overload
      cleanupTime = cleanupTime + 5.minutes

      req = BsRequest.new_from_xml( '<request>
                                       <action type="delete">
                                          <target project="' +  prj.name + '" />
                                       </action>
                                       <description>'+Description+'</description>
                                       <state who="Admin" name="new"/>
                                       <accept_at>' + cleanupTime.to_s + '</accept_at>
                                     </request>')
      req.save!
    end
  end

end

