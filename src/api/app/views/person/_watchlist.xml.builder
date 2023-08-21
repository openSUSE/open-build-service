builder.watchlist do
  my_model.watched_projects.each do |project|
    builder.project(name: project.name)
  end
  my_model.watched_packages.each do |package|
    builder.package(name: package.name, project: package.project.name)
  end
  my_model.watched_requests.each do |request|
    builder.request(number: request.number)
  end
end
