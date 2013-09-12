# -*- encoding: utf-8 i*-
require 'api_exception'
require 'builder/xchar'

class Package < ActiveRecord::Base
  include FlagHelper
  include CanRenderModel
  include HasRelationships
  include HasRatings
  include HasAttributes

  class CycleError < APIException
   setup "cycle_error"
  end
  class DeleteError < APIException
    attr_accessor :packages
    setup "delete_error"
  end
  class SaveError < APIException
    setup "package_save_error"
  end
  class WritePermissionError < APIException
    setup "package_write_permission_error"
  end
  class ReadAccessError < APIException
    setup 'unknown_package', 404, "Unknown package"
  end
  class UnknownObjectError < APIException
    setup 'unknown_package', 404, "Unknown package"
  end
  class ReadSourceAccessError < APIException
    setup 'source_access_no_permission', 403, "Source Access not allowed"
  end
  belongs_to :project, foreign_key: :db_project_id, inverse_of: :packages
  delegate :name, to: :project, prefix: true

  has_many :messages, :as => :db_object, dependent: :delete_all

  has_many :taggings, :as => :taggable, dependent: :delete_all
  has_many :tags, :through => :taggings

  has_many :download_stats

  has_many :flags, -> { order(:position) }, dependent: :delete_all, foreign_key: :db_package_id

  belongs_to :develpackage, :class_name => "Package", :foreign_key => 'develpackage_id'
  has_many  :develpackages, :class_name => "Package", :foreign_key => 'develpackage_id'

  has_many :attribs, :dependent => :destroy, foreign_key: :db_package_id

  has_many :package_kinds, :dependent => :destroy, foreign_key: :db_package_id
  has_many :package_issues, :dependent => :destroy, foreign_key: :db_package_id # defined in sources

  has_many :products, :dependent => :destroy
  has_many :channels, :dependent => :destroy, foreign_key: :package_id

  has_many :comments, :dependent => :destroy

  after_save :write_to_backend
  before_update :update_activity
  after_rollback :reset_cache

  default_scope { where("packages.db_project_id not in (?)", Relationship.forbidden_project_ids ) }

  validates :name, presence: true, length: { maximum: 200 }
  validate :valid_name

  has_one :linked_package, foreign_key: :package_id, dependent: :destroy
  delegate :links_to, to: :linked_package

  class << self

    def check_access?(dbpkg=self)
      return false if dbpkg.nil?
      return false unless dbpkg.class == Package
      return Project.check_access?(dbpkg.project)
    end

    def check_cache(project, package, opts)
      @key = { "get_by_project_and_name" => 1, package: package, opts: opts }

      @key[:user] = User.current.cache_key if User.current

      # the cache is only valid if the user, prj and pkg didn't change
      if project.is_a? Project
        @key[:project] = project.id
      else
        @key[:project] = project
      end
      pid, old_pkg_time, old_prj_time = Rails.cache.read(@key)
      if pid
        pkg=Package.where(id: pid).first
        return pkg if pkg && pkg.updated_at == old_pkg_time && pkg.project.updated_at == old_prj_time
        Rails.cache.delete(@key) # outdated anyway
      end
      return nil
    end

    def internal_get_project(project)
      if project.is_a? Project
        prj = project
      else
        return nil if Project.is_remote_project?( project )
        prj = Project.get_by_name( project )
      end
      raise UnknownObjectError, "#{project}/#{package}" unless prj
      prj
    end

    # returns an object of package or raises an exception
    # should be always used when a project is required
    # in case you don't access sources or build logs in any way use 
    # use_source: false to skip check for sourceaccess permissions
    # function returns a nil object in case the package is on remote instance
    def get_by_project_and_name( project, package, opts = {} )
      opts = { use_source: true, follow_project_links: true }.merge(opts)

      pkg = check_cache( project, package, opts )
      return pkg if pkg

      prj = internal_get_project(project)
      return nil unless prj # remote prjs

      if opts[:follow_project_links]
        pkg = prj.find_package(package)
      else
        pkg = prj.packages.find_by_name(package)
      end
      if pkg.nil? and opts[:follow_project_links]
        # in case we link to a remote project we need to assume that the
        # backend may be able to find it even when we don't have the package local
        prj.expand_all_projects.each do |p|
          return nil unless p.is_a? Project
        end
      end

      raise UnknownObjectError, "#{project}/#{package}" unless pkg
      raise ReadAccessError, "#{project}/#{package}" unless check_access?(pkg)

      pkg.check_source_access! if opts[:use_source]

      Rails.cache.write(@key, [pkg.id, pkg.updated_at, prj.updated_at])
      return pkg
    end

    def get_by_project_and_name!( project, package, opts = {} )
      pkg = get_by_project_and_name(project, package, opts)
      raise UnknownObjectError, "#{project}/#{package}" unless pkg
      pkg
    end

    # to check existens of a project (local or remote)
    def exists_by_project_and_name( project, package, opts = {} )
      raise "get_by_project_and_name expects a hash as third arg" unless opts.kind_of? Hash
      opts = { follow_project_links: true, allow_remote_packages: false}.merge(opts)
      if Project.is_remote_project?( project )
        return opts[:allow_remote_packages] && exist_package_on_backend?(package, project)
      end
      prj = Project.get_by_name( project )
      if opts[:follow_project_links]
        pkg = prj.find_package(package)
      else
        pkg = prj.packages.find_by_name(package)
      end
      if pkg.nil?
        # local project, but package may be in a linked remote one
        return opts[:allow_remote_packages] && exist_package_on_backend?(package, project)
      end
      unless check_access?(pkg)
        return false
      end
      return true
    end

    def exist_package_on_backend?(package, project)
      begin
        answer = Suse::Backend.get("/source/#{URI.escape(project)}/#{URI.escape(package)}")
        return true if answer
      rescue ActiveXML::Transport::Error
      end
      return false
    end

    def find_by_project_and_name( project, package )
      return Package.where(name: package.to_s, projects: { name: project }).includes(:project).first
    end

    def find_by_attribute_type( attrib_type, package=nil )
      # One sql statement is faster than a ruby loop
      # attribute match in package or project
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attribs attrprj ON pack.db_project_id = attrprj.db_project_id
      WHERE ( attr.attrib_type_id = ? or attrprj.attrib_type_id = ? )
      END_SQL

      if package
        sql += " AND pack.name = ? GROUP by pack.id"
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless Package.check_access?(dbpkg)
      end
      return ret
    end

    def find_by_attribute_type_and_value( attrib_type, value, package=nil )
      # One sql statement is faster than a ruby loop
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.db_package_id
      LEFT OUTER JOIN attrib_values val ON attr.id = val.attrib_id
      WHERE attr.attrib_type_id = ? AND val.value = ?
      END_SQL

      if package
        sql += " AND pack.name = ?"
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, value.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += " GROUP by pack.id"
      ret = Package.find_by_sql [sql, attrib_type.id.to_s, value.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless Package.check_access?(dbpkg)
      end
      return ret
    end

  end # self

  def check_source_access?
    if self.disabled_for?('sourceaccess', nil, nil) or self.project.disabled_for?('sourceaccess', nil, nil)
      unless User.current && User.current.can_source_access?(self)
        return false
      end
    end
    return true
  end

  def check_source_access!
    if !self.check_source_access?
      raise ReadSourceAccessError, "#{self.project.name}/#{self.name}"
    end
  end
  
  def is_locked?
    return true if flags.find_by_flag_and_status "lock", "enable"
    return self.project.is_locked?
  end

  def check_write_access!
    return if Rails.env.test? and User.current.nil? # for unit tests

    unless User.current.can_modify_package? self
      raise WritePermissionError, "No permission to modify package '#{self.name}' for user '#{User.current.login}'"
    end
  end

  # NOTE: this is no permission check, should it be added ?
  def can_be_deleted?
    # check if other packages have me as devel package
    msg = ""
    packs = []
    self.develpackages.each do |dpkg|
      msg += dpkg.project.name + "/" + dpkg.name + ", "
      packs << dpkg
    end
    unless msg.blank?
      de = DeleteError.new "Package is used by following packages as devel package: #{msg}"
      de.packages = packs
      raise de
    end
  end

  def find_project_local_linking_packages
    find_linking_packages(1)
  end

  def find_linking_packages(project_local=nil)
    path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(self.name)}\"+and+linkinfo/@project=\"#{CGI.escape(self.project.name)}\""
    path += "+and+@project=\"#{CGI.escape(self.project.name)}\"" if project_local
    path += ")"
    answer = Suse::Backend.post path, nil
    data = REXML::Document.new(answer.body)
    result = []

    data.elements.each("collection/package") do |e|
      p = Package.find_by_project_and_name( e.attributes["project"], e.attributes["name"] )
      if p.nil?
        logger.error "read permission or data inconsistency, backend delivered package as linked package where no database object exists: #{e.attributes["project"]} / #{e.attributes["name"]}"
      else
        result.push( p )
      end
    end

    return result
  end

  def sources_changed
    self.set_package_kind
    self.update_activity
  end

  def set_package_kind( kinds = nil )
    check_write_access!
    private_set_package_kind( kinds )
  end

  def set_package_kind_from_commit( commit )
    check_write_access!
    private_set_package_kind( nil, commit )
  end

  def self.source_path(project, package, file = nil)
    path = "/source/#{URI.escape(project)}/#{URI.escape(package)}"
    path += "/#{URI.escape(file)}" unless file.blank?
    path
  end

  def source_path(file = nil)
    Package.source_path(self.project.name, self.name, file)
  end

  def source_file(file)
    Suse::Backend.get(source_path(file)).body
  end

  def dir_hash
    begin
      directory = Suse::Backend.get(self.source_path).body
      Xmlhash.parse(directory)
    rescue ActiveXML::Transport::Error => e
      Xmlhash::XMLHash.new error: e.summary 
    end
  end

  def private_set_package_kind( kinds=nil, directory=nil, _noreset=nil )
    if kinds
      # set to given value
      Package.transaction do
        self.package_kinds.destroy_all unless _noreset
        kinds.each do |k|
          self.package_kinds.create :kind => k
        end
      end
    else
      # none given, detect by existing UNEXPANDED sources
      Package.transaction do
        self.package_kinds.destroy_all unless _noreset
        if directory
          xml = Xmlhash.parse(directory)
        else
          xml = self.dir_hash
        end
        xml.elements("entry") do |e|
          if e["name"] == '_patchinfo'
            self.package_kinds.create :kind => 'patchinfo'
          end
          if e["name"] == '_aggregate'
            self.package_kinds.create :kind => 'aggregate'
          end
          if e["name"] == '_link'
            self.package_kinds.create :kind => 'link'
          end
          if e["name"] == '_channel'
            self.package_kinds.create :kind => 'channel'
          end
          if e["name"] =~ /.product$/
            self.package_kinds.create :kind => 'product'
          end
          # further types my be spec, dsc, kiwi in future
        end
      end
    end

    # track defined products in _product containers
    Product.transaction do
      self.products.destroy_all
      if self.package_kinds.find_by_kind 'product'
        begin
          issues = Suse::Backend.get("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}?view=products")
          xml = REXML::Document.new(issues.body.to_s)
          xml.root.elements.each('/productlist/productdefinition/products/product') { |p|
            Product.find_or_create_by_name_and_package( p.name, self )
          }
        rescue ActiveXML::Transport::Error
        end
      end
    end # end of Product.transaction

    # update channel information
    if self.package_kinds.find_by_kind 'channel'
      Channel.transaction do
        xml = Suse::Backend.get("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}/_channel")
        self.channels.destroy_all
        channel = self.channels.create(package: self)
        channel.update_from_xml(xml.body.to_s)
      end
    else
      # any left overs?
      self.channels.destroy_all
    end

    # update issue database based on file content
    PackageIssue.transaction do
    if self.package_kinds.find_by_kind 'patchinfo'
      xml = Patchinfo.new.read_patchinfo_xmlhash(self)
      Project.transaction do
        self.package_issues.destroy_all
        xml.elements('issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i['id'], i['tracker'] )
          self.package_issues.create( :issue => issue, :change => "kept" )
        }
      end
    else
      # onlyissues gets the issues from .changes files
      issue_change={}
      # all 
      begin
        # no expand=1, so only branches are tracked
        issues = Suse::Backend.post("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}?cmd=diff&orev=0&onlyissues=1&linkrev=base&view=xml", nil)
        xml = REXML::Document.new(issues.body.to_s)
        xml.root.elements.each('/sourcediff/issues/issue') { |i|
          issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
          issue_change[issue] = 'kept' 
        }
      rescue ActiveXML::Transport::Error
      end

      # issues introduced by local changes
      if self.package_kinds.find_by_kind 'link'
        begin
          issues = Suse::Backend.post("/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}?cmd=linkdiff&linkrev=base&onlyissues=1&view=xml", nil)
          xml = REXML::Document.new(issues.body.to_s)
          xml.root.elements.each('/sourcediff/issues/issue') { |i|
            issue = Issue.find_or_create_by_name_and_tracker( i.attributes['name'], i.attributes['tracker'] )
            issue_change[issue] = i.attributes['state']
          }
        rescue ActiveXML::Transport::Error
        end
      end

      # store all
      Project.transaction do
        self.package_issues.destroy_all
        issue_change.each do |issue, change|
          self.package_issues.create( :issue => issue, :change => change )
        end
      end
    end
    end # end if PackageIssues.transaction
  end
  private :private_set_package_kind

  def resolve_devel_package
    pkg = self
    prj_name = pkg.project.name
    processed = {}

    if pkg == pkg.develpackage
      raise CycleError.new "Package defines itself as devel package"
    end
    while ( pkg.develpackage or pkg.project.develproject )
      #logger.debug "resolve_devel_package #{pkg.inspect}"

      # cycle detection
      str = prj_name+"/"+pkg.name
      if processed[str]
        processed.keys.each do |key|
          str = str + " -- " + key
        end
        raise CycleError.new "There is a cycle in devel definition at #{str}"
      end
      processed[str] = 1
      # get project and package name
      if pkg.develpackage
        # A package has a devel package definition
        pkg = pkg.develpackage
        prj_name = pkg.project.name
      else
        # Take project wide devel project definitions into account
        prj = pkg.project.develproject
        prj_name = prj.name
        pkg = prj.packages.get_by_name(pkg.name)
        if pkg.nil?
          return nil
        end
      end
      if pkg.id == self.id
        pkg = self
      end
    end
    #logger.debug "WORKED - #{pkg.inspect}"
    return pkg
  end

  def update_from_xml( xmlhash )
    check_write_access!

    self.title = xmlhash.value('title')
    self.description = xmlhash.value('description')
    self.bcntsynctag = xmlhash.value('bcntsynctag')

    #--- devel project ---#
    self.develpackage = nil
    if devel = xmlhash['devel']
      prj_name = devel['project'] || xmlhash['project']
      pkg_name = devel['package'] || xmlhash['name']
      unless develprj = Project.find_by_name(prj_name)
        raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
      end
      unless develpkg = develprj.packages.find_by_name(pkg_name)
        raise SaveError, "value of develpackage has to be a existing package (package '#{pkg_name}' does not exist)"
      end
      self.develpackage = develpkg
    end
    #--- end devel project ---#
    
    # just for cycle detection
    self.resolve_devel_package

    # give ourselves an ID
    self.save!

    update_relationships_from_xml( xmlhash )

    #---begin enable / disable flags ---#
    update_all_flags(xmlhash)
    
    #--- update url ---#
    self.url = xmlhash.value('url')
    #--- end update url ---#
    
    save!
  end

  # for the HasAttributes mixing
  def attribute_url
    "/source/#{CGI.escape(self.project.name)}/#{CGI.escape(self.name)}/_attribute"
  end

  def store(opts = {})
    # no write access check here, since this operation may will disable this permission ...
    @commit_opts = opts
    save!
  end

  def reset_cache
    Rails.cache.delete('xml_package_%d' % id)
  end

  def write_to_backend
    reset_cache
    @commit_opts ||= {}
    #--- write through to backend ---#
    if CONFIG['global_write_through']
      path = "/source/#{self.project.name}/#{self.name}/_meta?user=#{CGI.escape(User.current ? User.current.login : "_nobody_")}"
      path += "&comment=#{CGI.escape(@commit_opts[:comment])}" unless @commit_opts[:comment].blank?
      Suse::Backend.put_source( path, to_axml )
    end
    @commit_opts = {}
  end

  def to_axml_id
    return "<package project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>"
  end

  def render_xml(view = nil)
    super(view: view) # CanRenderModel
  end

  def to_axml(view = nil)
    if view
      render_xml(view)
    else
      Rails.cache.fetch('xml_package_%d' % self.id) do
        render_xml(view)
      end
    end
  end

  def self.activity_algorithm
    # this is the algorithm (sql) we use for calculating activity of packages
    # we use Time.now.to_i instead of UNIX_TIMESTAMP() so we can test with frozen ruby time
    "( packages.activity_index * " +
      "POWER( 2.3276, (UNIX_TIMESTAMP(packages.updated_at) - #{Time.now.to_i})/10000000 ) " +
      ") as activity_value"
  end

  before_validation(on: :create) do
    # it lives but is new
    self.activity_index = 20
  end

  def activity
    package = Package.find_by_sql("SELECT packages.*, #{Package.activity_algorithm} " +
                                  "FROM `packages` WHERE id = #{self.id} LIMIT 1")
    return package.shift.activity_value.to_f
  end

  # is called before_update
  def update_activity
    # the value we add to the activity, when the object gets updated
    addon = 10 * (Time.now.to_f - self.updated_at_was.to_f) / 86400
    addon = 10 if addon > 10
    logger.debug "update_activity #{activity} #{addon} #{Time.now} #{self.updated_at} #{self.updated_at_was}"
    new_activity = activity + addon
    new_activity = 100 if new_activity > 100

    # rails 3 only - rails 4 is reported to name it update_columns
    self.update_column(:activity_index, new_activity)
    # we need to update the timestamp manually to avoid the activity_algorithm to run away
    self.update_column(:updated_at, Time.now)
    # just for Schönheit - and only saved if we save it for other reasons
    self.update_counter += 1
  end

  def expand_flags
    return project.expand_flags(self)
  end

  def open_requests_with_package_as_source_or_target
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where("(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?) or (bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)", self.project.name, self.name, self.project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").map { |r| r.id})
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", self.project.name, self.name)
    return BsRequest.where(id: rel.select("bs_requests.id").map { |r| r.id})
  end

  def linkinfo
    dir = Directory.find( :project => self.project.name, :package => self.name )
    return nil unless dir
    return dir.to_hash['linkinfo']
  end

  def add_channels
     project_name = self.project.name
     package_name = self.name
     dir = self.dir_hash
     if dir
       # link target package name is more important, since local name could be
       # extended. for example in maintenance incident projects.
       li = dir['linkinfo']
       if li
         project_name = li['project']
         package_name = li['package']
       end
     end
     maintenanceProject=self.project.find_parent
     ChannelBinary.find_by_project_and_package( project_name, package_name ).each do |cb|
       cp = cb.channel_binary_list.channel.package
       name = cb.channel_binary_list.channel.name

       # does it exist already? then just skip it
       next if Package.exists_by_project_and_name(self.project.name, name)

       # do we need to take care about a maintained list from upper project?
       if maintenanceProject and not maintenanceProject.maintained_projects.include? cp.project
         # not a maintained project here
         next
       end

       # create a package beside me
       tpkg = Package.new(:name => name, :title => cp.title, :description => cp.description)
       self.project.packages << tpkg
       tpkg.store

       # branch sources
       tpkg.branch_from(cp.project.name, cp.name)
       tpkg.sources_changed

       # branch repositories
       self.project.branch_to_repositories_from(cp.project, tpkg, true)

       self.project.store
     end
  end

  def developed_packages
    packages = []
    candidates = Package.where(develpackage_id: self).load
    logger.debug candidates.inspect
    candidates.each do |candidate|
      packages << candidate unless candidate.linkinfo
    end
    return packages
  end

  def self.valid_name?(name)
    return false unless name.kind_of? String
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200 || name.blank?
    return true if name =~ /\A_product:\w[-+\w\.]*\z/
    # obsolete, just for backward compatibility
    return true if name =~ /\A_patchinfo:\w[-+\w\.]*\z/
    return false if name =~ %r{[ \/:\000-\037]}
    if name =~ %r{^[_\.]} && !['_product', '_pattern', '_project', '_patchinfo'].include?(name)
      return false
    end
    return name =~ /\A\w[-+\w\.]*\z/
  end

  def valid_name
    errors.add(:name, "is illegal") unless Package.valid_name?(self.name)
  end

  def branch_from(origin_project, origin_package, rev=nil, missingok=nil, comment=nil)
        path = "/source/#{URI.escape(self.project.name)}/#{URI.escape(self.name)}"
        myparam = { :cmd => "branch",
                    :noservice => "1",
                    :oproject => origin_project,
                    :opackage => origin_package,
                    :user => User.current.login,
                  }
        myparam[:orev] = rev if rev and not rev.empty?
        myparam[:missingok] = "1" if missingok
        myparam[:comment] = comment if comment
        path <<  Suse::Backend.build_query_from_hash(myparam, [:cmd, :oproject, :opackage, :user, :comment, :orev, :missingok])
        # branch sources in backend
        return Suse::Backend.post path, nil
  end

  def update_linkinfo
     dir = self.dir_hash
     # we will later delete all links not touched, so just go to return here
     return if dir.blank?
     li = dir['linkinfo']
     if !li
        self.linked_package.delete if self.linked_package
        return
     end
     Rails.logger.debug "Syncing link #{self.project.name}/#{self.name} -> #{li['project']}/#{li['package']}"
     # we have to be careful - the link target can be nowhere
     link = Package.find_by_project_and_name(li['project'], li['package'])
     unless link
       self.linked_package.delete if self.linked_package
       return
     end

     self.linked_package ||= LinkedPackage.new(links_to: link)
     self.linked_package.save # update updated_at

  end

  # FIXME: we REALLY should use active_model_serializers
  def as_json(options = nil)
    if options
      if options.key?(:methods)
        if options[:methods].kind_of? Array
          options[:methods] << :project_name unless options[:methods].include?(:project_name)
        elsif options[:methods] != :project_name
          options[:methods] = [options[:methods]] + [:project_name]
        end
      else
        options[:methods] = [:project_name]
      end
      super(options)
    else
      super(methods: [:project_name])
    end
  end
end
