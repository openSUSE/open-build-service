#very close to _tagged_objects_with_tags.xml
if @tag.class == Tag
  @tag = @tag.name
end 


xml.collection(:tag => @tag) do

  if @projects
    @projects.each do |project|
      xml.project(:name => project.name, :title => project.title ) do
        project.tags.each do |tag|
          xml.tag(:name => tag.name)
        end
     end
    end
  end
  
  if @packages 
    @packages.each do |package|
      xml.package(:project => package.project.name, :name => package.name, :title => package.title ) do
        package.tags.each do |tag|
          xml.tag(:name => tag.name)
        end
      end
    end
  end

end
