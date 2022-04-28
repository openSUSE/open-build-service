builder.watchlist do
  WatchlistFinder.new.watchlist_projects(my_model).each do |project|
    builder.project(name: project.name)
  end
  WatchlistFinder.new.watchlist_packages(my_model).each do |package|
    builder.package(name: package.name, project: package.project.name)
  end
  WatchlistFinder.new.watchlist_requests(my_model).each do |request|
    builder.request(number: request.number)
  end
end
