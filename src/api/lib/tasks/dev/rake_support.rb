module RakeSupport
  def self.create_and_assign_project(project_name, user)
    create(:project, name: project_name).tap do |project|
      create(:relationship, project: project, user: user, role: Role.hashed['maintainer'])
    end
  end

  def self.find_or_create_project(project_name, user)
    project = Project.joins(:relationships)
                     .where(projects: { name: project_name }, relationships: { user: user }).first
    return project if project

    create_and_assign_project(project_name, user)
  end

  def self.copy_example_file(example_file)
    if File.exist?(example_file) && !ENV['FORCE_EXAMPLE_FILES']
      example_file = File.join(File.expand_path(File.dirname(__FILE__) + '/../..'), example_file)
      puts "WARNING: You already have the config file #{example_file}, make sure it works with docker"
    else
      puts "Creating config/#{example_file} from config/#{example_file}.example"
      FileUtils.copy_file("#{example_file}.example", example_file)
    end
  end
end
