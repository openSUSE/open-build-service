builder.broken_packages(count: count) do |broken_package|
  broken_packages.each do |package|
    broken_package.package(package: package[:package], project: package[:project], state: package[:state],
                           repository: package[:repository], arch: package[:arch])
  end
end
