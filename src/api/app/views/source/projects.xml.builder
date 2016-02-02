xml.directory() do
  @projects.map { |project| xml.entry(name: project) }
end

