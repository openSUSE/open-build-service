xml.comments(project: @obj.project.name, package: @obj.name) do 
  render(partial: 'comments', locals: { builder: xml, comments: @comments })
end
