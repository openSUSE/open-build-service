xml.comments(request: @obj.id) do 
  render(partial: 'comments', locals: { builder: xml, comments: @comments })
end
