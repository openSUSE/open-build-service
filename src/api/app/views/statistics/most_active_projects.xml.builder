

xml.most_active do
  @projects.each do |project|
    xml.project(
      activity: project[1][:activity],
      packages: project[1][:count],
      name: project[0]
    )
  end
end
