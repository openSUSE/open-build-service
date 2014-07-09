class Repository < ActiveRecord::Base

  belongs_to :project, foreign_key: :db_project_id, inverse_of: :repositories

  before_destroy :cleanup_before_destroy

  has_many :release_targets, :class_name => "ReleaseTarget", :dependent => :delete_all, :foreign_key => 'repository_id'
  has_many :path_elements, -> { order("position") }, foreign_key: 'parent_id', dependent: :delete_all, inverse_of: :repository
  has_many :links, :class_name => "PathElement", :foreign_key => 'repository_id', inverse_of: :link
  has_many :targetlinks, :class_name => "ReleaseTarget", :foreign_key => 'target_repository_id'
  has_many :download_stats
  has_one :hostsystem, :class_name => "Repository", :foreign_key => 'hostsystem_id'
  has_many :binary_releases, :dependent => :destroy
  has_many :product_update_repositories, dependent: :delete_all
  has_many :product_medium, dependent: :delete_all
  has_many :repository_architectures, -> { order("position") }, :dependent => :destroy, inverse_of: :repository
  has_many :architectures, -> { order("position") }, :through => :repository_architectures

  scope :not_remote, -> { where(:remote_project_name => nil) }

  validate :validate_duplicates, :on => :create
  def validate_duplicates
    if Repository.where("db_project_id = ? AND name = ? AND ( remote_project_name = ? OR remote_project_name is NULL)", self.db_project_id, self.name, self.remote_project_name).first
      errors.add(:project, "already has repository with name #{self.name}")
    end
  end

  def cleanup_before_destroy
    # change all linking repository pathes
    del_repo = nil
    self.linking_repositories.each do |lrep|
      lrep.path_elements.includes(:link, :repository).each do |pe|
        next unless pe.link == self # this is not pointing to our repo
        del_repo ||= Project.find_by_name("deleted").repositories[0]
        if lrep.path_elements.where(repository_id: del_repo).size > 0
          # repo has already a path element pointing to del_repo
          pe.destroy 
        else
          pe.link = del_repo
          pe.save
        end
      end
      lrep.project.store({:lowprio => true})
    end
    # target repos
    logger.debug "remove target repositories from repository #{self.project.name}/#{self.name}"
    self.linking_target_repositories.each do |lrep|
      lrep.targetlinks.includes(:target_repository, :repository).each do |rt|
        next unless rt.target_repository == self # this is not pointing to our repo
        del_repo ||= Project.find_by_name("deleted").repositories[0]
        repo = rt.repository
        if lrep.targetlinks.where(repository_id: del_repo).size > 0
          # repo has already a path element pointing to del_repo
          logger.debug "destroy release target #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.destroy 
        else
          logger.debug "set deleted repo for releasetarget #{rt.target_repository.project.name}/#{rt.target_repository.name}"
          rt.target_repository = del_repo
          rt.save
        end
        repo.project.store({:lowprio => true})
      end
    end
  end

  def update_binary_releases(key, time = Time.now)
    begin
      pt = ActiveSupport::JSON.decode(Suse::Backend.get("/notificationpayload/#{key}").body)
    rescue
      logger.error("Failed to parse package tracking information for #{key}")
      return
    end
     self.update_binary_releases_via_json(pt, time)
  end

  def update_binary_releases_via_json(json, time = Time.now)
    oldlist = BinaryRelease.get_all_current_binaries(self)
    processed_item = {} # we can not just remove it from relation
                        # delete would affect the object

    BinaryRelease.transaction do
      json.each do |binary|
        # identifier
        hash={ :binary_name => binary["name"],
               :binary_version => binary["version"],
               :binary_release => binary["release"],
               :binary_epoch => binary["epoch"],
               :binary_arch => binary["binaryarch"],
               :obsolete_time => nil
             }
        # check for existing entry
        existing = oldlist.where(hash)
        raise SaveError if existing.count > 1
        
        # compare with existing entry
        if existing.count == 1
          entry = existing.first
          if entry.medium               == binary["medium"] and
             entry.binary_disturl       == binary["disturl"] and
             entry.binary_supportstatus == binary["supportstatus"] and
             entry.binary_buildtime     == Time.at(binary["buildtime"]||0)
             # same binary, don't touch
             processed_item[entry.id] = true
             next
          end
          # same binary name and location, but different content
          entry.obsolete_time = time
          entry.save!
          processed_item[entry.id] = true
          hash[:operation] = "modified" # new entry will get "modified" instead of "added"
        end

        # complete hash for new entry
        hash[:medium] = binary["medium"]
        hash[:binary_releasetime] = time
        hash[:binary_buildtime] = nil
        hash[:binary_buildtime] = Time.at(binary["buildtime"].to_i) if binary["buildtime"].to_i > 0
        hash[:binary_disturl] = binary["disturl"]
        hash[:binary_supportstatus] = binary["supportstatus"]
        if binary["project"] and rp = Package.find_by_project_and_name(binary["project"], binary["package"])
          hash[:release_package_id] = rp.id
        end
        if binary["patchinforef"]
          begin
            pi = Patchinfo.new(Suse::Backend.get("/source/#{binary["patchinforef"]}/_patchinfo").body)
          rescue ActiveXML::Transport::NotFoundError
            # patchinfo disappeared meanwhile
          end
          # no database object on purpose, since it must also work for historic releases...
          hash[:binary_maintainer] = pi.to_hash['packager'] if pi and pi.to_hash['packager']
        end

        # new entry, also for modified binaries.
        entry = self.binary_releases.create(hash)
        processed_item[entry.id] = true
      end

      # and mark all not processed binaries as removed
      oldlist.each do |e|
        next if processed_item[e.id]
        e.operation = "removed"
        e.obsolete_time = time
        e.save!
      end
    end
  end

  class << self
    def find_by_project_and_repo_name( project, repo )
      result = not_remote.joins(:project).where(:projects => {:name => project}, :name => repo).first
      return result unless result.nil?

      #no local repository found, check if remote repo possible

      local_project, remote_project = Project.find_remote_project(project)
      if local_project
        return local_project.repositories.find_or_create_by(name: repo, remote_project_name: remote_project)
      end

      return nil
    end
  end

  #returns a list of repositories that include path_elements linking to this one
  #or empty list
  def linking_repositories
    return [] if links.size == 0
    links.map {|l| l.repository}
  end

  def linking_target_repositories
    return [] if targetlinks.size == 0
    targetlinks.map {|l| l.target_repository}
  end

  def extended_name
    longName = self.project.name.gsub(':', '_')
    if self.project.repositories.count > 1
      # keep short names if project has just one repo
      longName += '_'+self.name unless self.name == 'standard'
    end
    return longName
  end

  def to_axml_id
    return "<repository project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>"
  end

  def to_s
    name
  end

end
