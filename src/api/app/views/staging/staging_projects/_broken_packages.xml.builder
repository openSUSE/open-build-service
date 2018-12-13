builder.broken_package(count: count) do |broken_package|
  broken_packages.each do |package|
    broken_package.entry(package: package[:package], project: package[:project])
  end
end
