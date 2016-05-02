xml.comments(request: @obj.number) do 
  render(partial: 'comments', locals: { builder: xml, comments: @comments })
end
