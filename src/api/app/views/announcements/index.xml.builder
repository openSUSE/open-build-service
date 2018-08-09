xml.announcements do
  @announcements.each do |announcement|
    xml << render(template: 'announcements/show', locals: { announcement: announcement })
  end
end
