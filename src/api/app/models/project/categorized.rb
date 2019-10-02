class Project::Categorized
  def self.very_important_projects_with_categories
    Project.very_important_projects_with_attributes.map do |p|
      [p.name, p.title, p.categories]
    end
  end
end
