xml.announcements do
  render(partial: 'announcement', collection: @announcements, locals: { builder: xml })
end
