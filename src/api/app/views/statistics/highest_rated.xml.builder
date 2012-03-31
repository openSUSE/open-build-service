

xml.highest_rated do

  @ratings.each do |rating|

    if rating.object_type == 'DbPackage'
      xml.package(
        :score => rating.score_calculated,
        :count => rating.count,
        :project => rating.db_packages.db_project.name,
        :name => rating.db_packages.name
      )
    elsif rating.object_type == 'DbProject'
      xml.project(
        :score => rating.score_calculated,
        :count => rating.count,
        :name => rating.db_projects.name
      )
    end

  end

end

