class Project::Categorized
  def self.vips_with_categories
    Project.vips_with_attributes.map do |p|
      [p.name, p.title, p.categories]
    end
  end
end
