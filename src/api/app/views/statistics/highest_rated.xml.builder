

xml.highest_rated do
  @ratings.each do |rating|
    if rating.object_type == 'Package'
      xml.package(
        :score => rating.score_calculated,
        :count => rating.count,
        :project => rating.packages.project.name,
        :name => rating.packages.name
      )
    elsif rating.object_type == 'Project'
      xml.project(
        :score => rating.score_calculated,
        :count => rating.count,
        :name => rating.projects.name
      )
    end
  end
end

