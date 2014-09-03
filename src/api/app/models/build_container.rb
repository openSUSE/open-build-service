require 'api_exception'
require 'builder/xchar'
require 'rexml/document'

class BuildContainer < ActiveRecord::Base
  belongs_to :package, foreign_key: 'package_id'
  belongs_to :project, foreign_key: 'local_project_id'
  belongs_to :repository_architecture, foreign_key: 'repository_architecture_id'

  def self.find_or_create_by_package_repo_and_arch( package, repository, architecture )
    obj = self.find_by_package_repo_and_arch( package, repository, architecture )
    if obj.empty?
      # we store also the local project here to allow fast lookups for projects independend if they
      # are building local or remote packages or even mixed ones.
      obj = self.create(local_project: package.project, package: package, repository: repository, architecture: architecture)
    end

    return obj.load
  end

  def self.find_by_package_repo_and_arch( package, repository, architecture )
    raise NotFoundError.new( "Error: Package not valid." ) unless package.kind_of? Package
    raise NotFoundError.new( "Error: Repository not valid." ) unless repository.kind_of? Repository
    raise NotFoundError.new( "Error: Architecture not valid." ) unless architecture.kind_of? Architecture
    obj = self.joins(:repository_architecture).where(package: package, remote_package: nil, repository_architectures: {repository_id: repository.id, architecture_id: architecture.id})

    return nil if obj.empty?
    return obj.load
  end

  def self.find_or_create_by_remote_package_repo_and_arch( project, package, repository, architecture )
    obj = self.find_by_remote_package_repo_and_arch( project, package, repository, architecture )
    if obj.empty?
      obj = self.create(local_project: project, remote_package: package, repository: repository, architecture: architecture)
    end

    return obj.load
  end

  def self.find_by_remote_package_repo_and_arch( local_project, package, repository, architecture )
    raise NotFoundError.new( "Error: Project not valid." ) unless project.kind_of? Project
    raise NotFoundError.new( "Error: Package not valid." ) unless package.kind_of? String
    raise NotFoundError.new( "Error: Repository not valid." ) unless repository.kind_of? Repository
    raise NotFoundError.new( "Error: Architecture not valid." ) unless architecture.kind_of? Architecture
    obj = self.joins(:repository_architecture).where(package_id: nil, local_project: project, remote_package: package, remote_package: package, repository_architectures: {repository_id: repository.id, architecture_id: architecture.id})

    return nil if obj.empty?
    return obj.load
  end

  def set_state(state)
    self.state = state
    self.save
  end

  def status
    return self.state
  end

end
