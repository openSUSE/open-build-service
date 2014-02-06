xml.comments(project: @obj.name) do 
  render(partial: 'comments', locals: { builder: xml, comments: @comments })
end
