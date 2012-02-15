class ProjectStatus < ActiveXML::Base
 
  to_hash_options :force_array => [:person, :failure], :key_attr => nil

end
