

xml.collection(:user => @user.login) do
  
  case @my_type 
    when "project"
       @projects_tags.keys.each do |key| 
          xml.project(:name => key.name, :title => CGI::escapeHTML(key.title) ) {
            @projects_tags[key].each do |tag|
              xml.tag(:name => CGI::escapeHTML(tag.name))
             end
           }
       end
    when "package"
       @packages_tags.keys.each do |key| 
          xml.package(:project => key.project.name , :name => key.name, :title => CGI::escapeHTML(key.title) ) {
             @packages_tags[key].each do |tag|
              xml.tag(:name => CGI::escapeHTML(tag.name))
             end
          }
       end
    end
end
