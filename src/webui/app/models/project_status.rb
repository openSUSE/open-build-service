class ProjectStatus < ActiveXML::Base
 
  # The following collides with the 'Project' model when a "Collection.find(:what => 'project', ...)" is done.
  # ProjectStatus is only used in one place anyway and not (yet) through the search interface, thus it won't hurt
  # currently:
  #handles_xml_element 'project'

end

