builder.building_repositories(count: count) do |building_repository|
  building_repositories.each do |repo|
    building_repository.repo(name: repo['repository'], arch: repo['arch'], code: repo['code'], state: repo['state'],
                             to_build: repo[:tobuild], final: repo[:final])
  end
end
