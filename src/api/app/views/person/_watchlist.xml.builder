builder.watchlist do
  ProjectsForWatchlistFinder.new.call(my_model).each do |project|
    builder.project(name: project.name)
  end
  PackagesForWatchlistFinder.new.call(my_model).each do |package|
    builder.package(name: package.name, project: package.project.name)
  end
  RequestsForWatchlistFinder.new.call(my_model).each do |request|
    builder.request(number: request.number)
  end
end
