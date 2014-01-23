class ProjectCreateAutoCleanupRequests

  Description="This is a kind request to remove this project.
  Accepting this request will free resources on our always crowded server.
  Please decline this request if you want to keep this repository nevertheless. Otherwise this request
  will get accept automatically in near future.
  It is possible to disable such requests for your project if you remove the OBS:AutoCleanup attribute."

  def initialize
  end

  def perform
    require 'opensuse/backend'
    User.current ||= User.find_by_login "Admin"

    at = AttribType.find_by_namespace_and_name("OBS", "AutoCleanup")

    cleanupDays = ::Configuration.first.cleanup_after_days
    cleanupTime = DateTime.now + cleanupDays.days
    # disabled ?
    return unless cleanupDays and cleanupDays > 0

    Project.find_by_attribute_type( at ).each do |prj|
      next if prj.nil?
      next if prj.is_locked?

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
      cleanupTime = cleanupTime + 3.minutes

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

