class ProjectNamesFinder
  def initialize(projects, relation = Project.all)
    @relation = relation
    @projects = projects
  end

  def call
    @relation.where(name: @projects).pluck(:name)
  end
end
