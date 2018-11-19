xml.building_repositories(count: count) do |building_repository|
  building_repositories.each do |repo|
    # missing , tobuild: repo[''], final: repo['']
    building_repository.entry(name: repo['repository'], arch: repo['arch'], code: repo['code'], state: repo['state'])
  end
end
