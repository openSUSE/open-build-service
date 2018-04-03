class Repository < ApplicationRecord
  belongs_to :project, foreign_key: :db_project_id, inverse_of: :repositories

  before_destroy :cleanup_before_destroy

  has_many :channel_targets, class_name: 'ChannelTarget', dependent: :delete_all, foreign_key: 'repository_id'
  has_many :release_targets, class_name: 'ReleaseTarget', dependent: :delete_all, foreign_key: 'repository_id'
  has_many :path_elements, -> { order('position') }, foreign_key: 'parent_id', dependent: :delete_all, inverse_of: :repository
  has_many :download_repositories, dependent: :delete_all, foreign_key: :repository_id
  has_many :links, class_name: 'PathElement', foreign_key: 'repository_id', inverse_of: :link
  has_many :targetlinks, class_name: 'ReleaseTarget', foreign_key: 'target_repository_id'
  has_one :hostsystem, class_name: 'Repository', foreign_key: 'hostsystem_id'
  has_many :binary_releases, dependent: :destroy
  has_many :product_update_repositories, dependent: :delete_all
  has_many :product_medium, dependent: :delete_all
  has_many :repository_architectures, -> { order('position') }, dependent: :destroy, inverse_of: :repository
  has_many :architectures, -> { order('position') }, through: :repository_architectures

  scope :not_remote, -> { where(remote_project_name: nil) }
  scope :remote, -> { where.not(remote_project_name: nil) }

  validates :name, length: { in: 1..200 }
  # Keep in sync with src/backend/BSVerify.pm
  validates :name, format: { with:    /\A[^_:\/\000-\037][^:\/\000-\037]*\Z/,
                             message: "must not start with '_' or contain any of these characters ':/'" }

  # Name has to be unique among local repositories and remote_repositories of the associated db_project.
  # Note that remote repositories have to be unique among their remote project (remote_project_name)
  # and the associated db_project.
  validates :name, uniqueness: { scope:   [:db_project_id, :remote_project_name],
                                 message: '%{value} is already used by a repository of this project' }

  validates :db_project_id, presence: true
  # NOTE: remote_project_name cannot be NULL because mysql UNIQUE KEY constraint does considers
  #       two NULL's to be distinct. (See mysql bug #8173)
  validate :remote_project_name_not_nill

  validate do |repository|
    repository.path_elements.reject(&:valid?).each do |path_element|
      path_element.errors.full_messages.each do |msg|
        errors[:base] << "Path Element: #{msg}"
      end
    end
  end

  # FIXME: Don't lie, it's find_or_create_by_project_and_name_if_project_is_remote
  def self.find_by_project_and_name(project, repo)
    result = not_remote.joins(:project).find_by(projects: { name: project }, name: repo)
    return result unless result.nil?

    # no local repository found, check if remote repo possible

    local_project, remote_project = Project.find_remote_project(project)
    if local_project
      return local_project.repositories.find_or_create_by(name: repo, remote_project_name: remote_project)
    end

    return
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

  def cleanup_before_destroy
    # change all linking repository pathes
    linking_repositories.each do |lrep|
      lrep.path_elements.includes(:link, :repository).each do |pe|
        next unless pe.link == self # this is not pointing to our repo
        if lrep.path_elements.where(repository_id: Repository.deleted_instance).present?
          # repo has already a path element pointing to deleted repository
          pe.destroy
        else
          pe.link = Repository.deleted_instance
          pe.save
        end
      end
      lrep.project.store(lowprio: true)
    end
    # target repos
    logger.debug "remove target repositories from repository #{project.name}/#{name}"
    linking_target_repositories.each do |lrep|
      lrep.targetlinks.includes(:target_repository, :repository).each do |rt|
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
        repo.project.store(lowprio: true)
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

  # returns a list of repositories that include path_elements linking to this one
  # or empty list
  def linking_repositories
    return [] if links.size.zero?
    links.map(&:repository)
  end

  def is_local_channel?
    # is any our path elements the target of a channel package in this project?
    path_elements.includes(:link).each do |pe|
      return true if ChannelTarget.find_by_repo(pe.link, [project]).any?
    end
    return true if ChannelTarget.find_by_repo(self, [project]).any?
    false
  end

  def linking_target_repositories
    return [] if targetlinks.size.zero?
    targetlinks.map(&:target_repository)
  end

  def extended_name
    long_name = project.name.tr(':', '_')
    if project.repositories.count > 1
      # keep short names if project has just one repo
      long_name += '_' + name unless name == 'standard'
    end
    long_name
  end

  def to_axml_id
    "<repository project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  def to_s
    name
  end

  def is_kiwi_type?
    # HACK: will be cleaned up after implementing FATE #308899
    name == 'images'
  end

  def has_local_path?
    path_elements.each do |pe|
      return true if pe.link.project == project
    end

    false
  end

  def clone_repository_from(source_repository)
    source_repository.repository_architectures.each do |ra|
      repository_architectures.create architecture: ra.architecture, position: ra.position
    end

    position = 1
    if source_repository.has_local_path?
      # don't link to the original external repo, but use the repo from this project
      # pointing to this external repo.
      source_repository.path_elements.each do |spe|
        next unless spe.link.project == source_repository.project
        local_repository = project.repositories.find_by_name(spe.link.name)
        path_elements.create(link: local_repository, position: position)
        position += 1
      end
    elsif source_repository.is_kiwi_type?
      # kiwi builds need to copy path elements
      source_repository.path_elements.each do |pa|
        path_elements.create(link: pa.link, position: pa.position)
      end
      # and set type in prjconf
      prjconf = project.source_file('_config')
      unless prjconf =~ /^Type:/
        prjconf = "%if \"%_repository\" == \"images\"\nType: kiwi\nRepotype: none\nPatterntype: none\n%endif\n" << prjconf
        Backend::Api::Sources::Project.write_configuration(project.name, prjconf)
      end
      return
    end

    # we build against the other repository by default
    path_elements.create(link: source_repository, position: position)
  end

  def download_url(file)
    url = Rails.cache.fetch("download_url_#{project.name}##{name}") do
      xml = Xmlhash.parse(Backend::Api::Published.download_url_for_repository(project.name, name))
      xml.elements('url').last.to_s
    end
    url + '/' + file if file.present?
  end

  def download_url_for_file(package, architecture, filename)
    Rails.cache.fetch("download_url_for_file_#{project.name}##{name}##{package.name}##{architecture}##{filename}") do
      xml = Xmlhash.parse(Backend::Api::BuildResults::Binaries.download_url_for_file(project.name, name, package.name, architecture, filename))
      xml.elements('url').last.to_s
    end
  end

  def is_dod_repository?
    download_repositories.any?
  end

  def remote_project_name_not_nill
    return unless remote_project_name.nil?
    errors.add :remote_project_name, 'cannot be nil'
  end
end

# == Schema Information
#
# Table name: repositories
#
#  id                  :integer          not null, primary key
#  db_project_id       :integer          not null, indexed => [name, remote_project_name]
#  name                :string(255)      not null, indexed => [db_project_id, remote_project_name]
#  remote_project_name :string(255)      default(""), not null, indexed => [db_project_id, name], indexed
#  rebuild             :string(10)
#  block               :string(5)
#  linkedbuild         :string(8)
#  hostsystem_id       :integer          indexed
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
