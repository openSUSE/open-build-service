#very close to _tagged_objects_with_tags.xml
if @tag.class == Tag
  @tag = @tag.name
end 

xml.instruct!

xml.collection(:tag => CGI::escapeHTML(@tag)) do

  if @projects
    @projects.each do |project|
      xml.project(:name => project.name, :title => CGI::escapeHTML(project.title) ) do
        project.tags.find(:all, :group => "name").each do |tag|
          xml.tag(:name => CGI::escapeHTML(tag.name))
        end
     end
    end
  end
  
  if @packages 
    @packages.each do |package|
      xml.package(:project => package.db_project.name, :name => package.name, :title => CGI::escapeHTML(package.title) ) do
        package.tags.find(:all, :group => "name").each do |tag|
          xml.tag(:name => CGI::escapeHTML(tag.name))
        end
      end
    end
  end

end