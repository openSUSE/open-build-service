xml.highest_rated do
  @ratings.each do |rating|
    case rating.object_type
    when 'Package'
      xml.package(
        score: rating.score_calculated,
        count: rating.count,
        project: rating.packages.project.name,
        name: rating.packages.name
      )
    when 'Project'
      xml.project(
        score: rating.score_calculated,
        count: rating.count,
        name: rating.projects.name
      )
    end
  end
end
