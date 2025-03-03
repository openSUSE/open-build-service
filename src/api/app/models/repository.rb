class Repository < ApplicationRecord
  include StatusCheckable

  belongs_to :project, foreign_key: :db_project_id, inverse_of: :repositories

  before_destroy :cleanup_before_destroy

  has_many :channel_targets, class_name: 'ChannelTarget', dependent: :delete_all
  has_many :release_targets, class_name: 'ReleaseTarget', dependent: :delete_all
  has_many :path_elements, -> { order('position') }, foreign_key: 'parent_id', dependent: :delete_all, inverse_of: :repository
  has_many :download_repositories, dependent: :delete_all
  has_many :links, class_name: 'PathElement', inverse_of: :link
  has_many :targetlinks, class_name: 'ReleaseTarget', foreign_key: 'target_repository_id'
  has_one :hostsystem, class_name: 'Repository', foreign_key: 'hostsystem_id'
  has_many :binary_releases, dependent: :destroy do
    def current
      where(obsolete_time: nil)
    end

    def obsolete
      where.not(obsolete_time: nil)
    end

    def unchanged
      where(modify_time: nil)
    end

    def changed
      where.not(modify_time: nil)
    end
  end
  has_many :product_update_repositories, dependent: :delete_all
  has_many :product_medium, dependent: :delete_all
  has_many :repository_architectures, -> { order('position') }, dependent: :destroy, inverse_of: :repository
  has_many :architectures, through: :repository_architectures

  scope :not_remote, -> { where(remote_project_name: '') }
  scope :remote, -> { where.not(remote_project_name: '') }

  validates :name, length: { in: 1..200 }
  # Keep in sync with src/backend/BSVerify.pm
  validates :name, format: { with: %r{\A[^_:/\000-\037][^:/\000-\037]*\Z},
                             message: "must not start with '_' or contain any of these characters ':/'" }

  # never used in production, but existed for quite some time...
  self.ignored_columns += ['hostsystem_id']

  # Name has to be unique among local repositories and remote_repositories of the associated db_project.
  # Note that remote repositories have to be unique among their remote project (remote_project_name)
  # and the associated db_project.
  validates :name, uniqueness: { scope: %i[db_project_id remote_project_name],
                                 case_sensitive: true,
                                 message: '%{value} is already used by a repository of this project' }
  # NOTE: remote_project_name cannot be NULL because mysql UNIQUE KEY constraint does considers
  #       two NULL's to be distinct. (See mysql bug #8173)
  validate :remote_project_name_not_nill

  validate do |repository|
    repository.path_elements.reject(&:valid?).each do |path_element|
      path_element.errors.full_messages.each do |msg|
        errors.add(:base, "Path Element: #{msg}")
      end
    end
  end

  # FIXME: Don't lie, it's find_or_create_by_project_and_name_if_project_is_remote
  def self.find_by_project_and_name(project, repo)
    result = not_remote.joins(:project).find_by(projects: { name: project }, name: repo)
    return result unless result.nil?

    # no local repository found, check if remote repo possible

    local_project, remote_project = Project.find_remote_project(project)
    return local_project.repositories.find_or_create_by(name: repo, remote_project_name: remote_project) if local_project

    nil
  end

  def self.find_by_project_and_name!(project, repo)
    result = find_by_project_and_name(project, repo)
    return ActiveRecord::RecordNotFound if result.blank?

    result
  end

  def self.find_by_project_and_path(project, path)
    not_remote.joins(:path_elements).where(project: project, path_elements: { link: path })
  end

  def self.deleted_instance
    repo = Repository.find_by_project_and_name('deleted', 'deleted')
    return repo unless repo.nil?

    # does not exist, so let's create it
    project = Project.deleted_instance
    project.repositories.find_or_create_by!(name: 'deleted')
  end

  def self.new_from_distribution(distribution)
    target_repository = find_by_project_and_name!(distribution.project, distribution.repository)
    distribution_repository = new(name: distribution.reponame)
    distribution_repository.path_elements.build(link: target_repository)
    distribution.architectures.each do |architecture|
      distribution_repository.repository_architectures.build(architecture: architecture)
    end

    distribution_repository
  end

  def cleanup_before_destroy
    # change all linking repository pathes
    linking_repositories.each do |lrep|
      lrep.path_elements.includes(:link, :repository).find_each do |pe|
        next unless pe.link == self # this is not pointing to our repo

        if lrep.path_elements.where(repository_id: Repository.deleted_instance).present?
          # repo has already a path element pointing to deleted repository
          pe.destroy
        else
          pe.link = Repository.deleted_instance
          pe.save
        end
      end
      lrep.project.store(lowprio: true) unless marked_for_destruction?
    end
    # target repos
    logger.debug "remove target repositories from repository #{project.name}/#{name}"
    linking_target_repositories.each do |lrep|
      lrep.targetlinks.includes(:target_repository, :repository).find_each do |rt|
        next unless rt.target_repository == self # this is not pointing to our repo

        repo = rt.repository
        if lrep.targetlinks.where(repository_id: Repository.deleted_instance).present?
          # repo has already a path element pointing to deleted repository
          logger.debug "destroy release target #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.destroy
        else
          logger.debug "set deleted repo for releasetarget #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.target_repository = Repository.deleted_instance
          rt.save
        end
        repo.project.store(lowprio: true) unless marked_for_destruction?
      end
    end
  end

  def project_name
    project.try(:name) || remote_project_name
  end

  def expand_all_repositories
    repositories = [self]
    # add all linked and indirect linked repositories
    links.each do |path_element|
      # skip self referencing repos to avoid loops
      next if path_element.repository_id == id

      path_element.repository.expand_all_repositories.each do |repo|
        repositories << repo
      end
    end
    repositories.uniq
  end

  # returns an array of arrays with package names that have circular dependencies with each other
  # [['firefox', 'gtk3'], ['kde', 'qt4']]
  def cycles(arch)
    # skip all packages via package=- to speed up the api call, we only parse the cycles anyway
    deps = Backend::Api::BuildResults::Binaries.builddepinfo(project.name, name, arch, '-')
    deps = Xmlhash.parse(deps)
    # if the backend has support for SCC calculation, we don't need to merge "cycles". The cycles
    # are incomplete anyway
    return deps.elements('scc').map! { |cycle| cycle.elements('package') } if deps.value('scc')

    cycles = deps.elements('cycle').map! { |cycle| cycle.elements('package') }

    merged_cycles = []
    cycles.each do |cycle|
      intersecting_cycles = merged_cycles.select { |another_cycle| cycle.intersect?(another_cycle) }
      intersecting_cycles.each do |intersecting_cycle|
        deleted = merged_cycles.delete(intersecting_cycle)
        cycle.concat(deleted)
      end
      cycle.sort!
      merged_cycles.push(cycle.uniq)
    end

    merged_cycles
  end

  # returns a list of repositories that include path_elements linking to this one
  # or empty list
  def linking_repositories
    return [] if links.empty?

    # FIXME: This is the same as using a `has_many through:` association
    links.map(&:repository)
  end

  def local_channel?
    # is any our path elements the target of a channel package in this project?
    path_elements.includes(:link).find_each do |pe|
      return true if ChannelTarget.find_by_repo(pe.link, [project]).any?
    end
    return true if ChannelTarget.find_by_repo(self, [project]).any?

    false
  end

  def hostsystem?
    path_elements.where(kind: :hostsystem).any?
  end

  def linking_target_repositories
    return [] if targetlinks.empty?

    # FIXME: This is the same as using a `has_many through:` association
    targetlinks.map(&:target_repository)
  end

  def extended_name
    long_name = project.name.tr(':', '_')
    if project.repositories.count > 1 && !(name == 'standard')
      # keep short names if project has just one repo
      long_name += "_#{name}"
    end
    long_name
  end

  def to_axml_id
    "<repository project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  def to_s
    name
  end

  def to_param
    name
  end

  def check_valid_release_target!(target_repository, architecture_filter = nil)
    # first architecture must be the same
    # not using "architectures" here becasue the position is critical
    unless repository_architectures.first.architecture == target_repository.repository_architectures.first.architecture
      raise ArchitectureOrderMissmatch, "Repository '#{name}' and releasetarget " \
                                        "'#{target_repository.name}' have a different architecture as first entry"
    end
    repository_architectures.each do |ra|
      next if architecture_filter.present? && ra.architecture.name != architecture_filter

      raise ArchitectureOrderMissmatch, "Release target repository lacks the architecture #{ra.architecture.name}" unless target_repository.architectures.include?(ra.architecture)
    end
  end

  def kiwi_type?
    # HACK: will be cleaned up after implementing FATE #308899
    name == 'images'
  end

  def local_path?
    path_elements.each do |pe|
      return true if pe.link.project == project
    end

    false
  end

  def clone_repository_from(source_repository)
    source_repository.repository_architectures.each do |ra|
      repository_architectures.create(architecture: ra.architecture, position: ra.position)
    end

    position = 1
    if source_repository.local_path?
      # don't link to the original external repo, but use the repo from this project
      # pointing to this external repo.
      source_repository.path_elements.where(kind: 'standard').find_each do |spe|
        next unless spe.link.project == source_repository.project

        local_repository = project.repositories.find_by_name(spe.link.name)
        path_elements.create(link: local_repository, position: position)
        position += 1
      end
    elsif source_repository.kiwi_type?
      # kiwi builds need to copy path elements
      source_repository.path_elements.each do |pa|
        path_elements.create(link: pa.link, position: pa.position, kind: pa.kind)
      end
      # and set type in prjconf
      prjconf = project.source_file('_config')
      unless /^Type:/.match?(prjconf)
        prjconf = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << prjconf
        Backend::Api::Sources::Project.write_configuration(project.name, prjconf)
      end
      return
    end

    # we build against the other repository by default
    path_elements.create(link: source_repository, position: position)
    path_elements.create(link: source_repository, position: position, kind: :hostsystem) if source_repository.hostsystem?
  end

  def download_url(file)
    xml = Xmlhash.parse(Backend::Api::Published.download_url_for_repository(project.name, name))
    url = xml.elements('url').last.to_s
    "#{url}/#{file}" if file.present?
  end

  def dod_repository?
    download_repositories.any?
  end

  def remote_project_name_not_nill
    return unless remote_project_name.nil?

    errors.add(:remote_project_name, 'cannot be nil')
  end

  def build_id
    Backend::Api::Published.build_id(project.name, name)
  end

  def copy_to(new_project)
    new_repository = deep_clone(include: %i[path_elements repository_architectures], skip_missing_associations: true)
    # DoD repositories require the architecture references to be stored
    new_repository.update!(db_project_id: new_project.id)
    new_repository.download_repositories = download_repositories.map(&:deep_clone)

    new_repository.reload
  end
end

# == Schema Information
#
# Table name: repositories
#
#  id                  :integer          not null, primary key
#  block               :string
#  linkedbuild         :string
#  name                :string(255)      not null, indexed => [db_project_id, remote_project_name]
#  rebuild             :string
#  remote_project_name :string(255)      default(""), not null, indexed => [db_project_id, name], indexed
#  required_checks     :string(255)
#  db_project_id       :integer          not null, indexed => [name, remote_project_name]
#
# Indexes
#
#  hostsystem_id              (hostsystem_id)
#  projects_name_index        (db_project_id,name,remote_project_name) UNIQUE
#  remote_project_name_index  (remote_project_name)
#
# Foreign Keys
#
#  repositories_ibfk_1  (db_project_id => projects.id)
#  repositories_ibfk_2  (hostsystem_id => repositories.id)
#
