# -*- encoding: utf-8 i*-
require_dependency 'api_exception'
require 'builder/xchar'
require 'rexml/document'
require_dependency 'has_relationships'

class Package < ActiveRecord::Base
  include FlagHelper
  include CanRenderModel
  include HasRelationships
  has_many :relationships, dependent: :destroy, inverse_of: :package

  include HasRatings
  include HasAttributes

  class CycleError < APIException
    setup 'cycle_error'
  end
  class DeleteError < APIException
    attr_accessor :packages
    setup 'delete_error'
  end
  class SaveError < APIException
    setup 'package_save_error'
  end
  class WritePermissionError < APIException
    setup 'package_write_permission_error'
  end
  class ReadAccessError < APIException
    setup 'unknown_package', 404, 'Unknown package'
  end
  class UnknownObjectError < APIException
    setup 'unknown_package', 404, 'Unknown package'
  end
  class ReadSourceAccessError < APIException
    setup 'source_access_no_permission', 403, 'Source Access not allowed'
  end
  belongs_to :project, inverse_of: :packages
  delegate :name, to: :project, prefix: true

  has_many :messages, :as => :db_object, dependent: :delete_all

  has_many :taggings, :as => :taggable, dependent: :delete_all
  has_many :tags, :through => :taggings

  has_many :download_stats

  has_many :flags, -> { order(:position) }, dependent: :delete_all, inverse_of: :package

  belongs_to :develpackage, :class_name => 'Package', :foreign_key => 'develpackage_id'
  has_many :develpackages, :class_name => 'Package', :foreign_key => 'develpackage_id'

  has_many :attribs, :dependent => :destroy, foreign_key: :package_id

  has_many :package_kinds, dependent: :delete_all
  has_many :package_issues, dependent: :delete_all # defined in sources
  has_many :issues, through: :package_issues

  has_many :products, :dependent => :destroy
  has_many :channels, :dependent => :destroy, foreign_key: :package_id

  has_many :comments, :dependent => :delete_all, inverse_of: :package

  before_destroy :delete_cache_lines
  before_destroy :remove_linked_packages

  after_save :write_to_backend
  before_update :update_activity
  after_rollback :reset_cache

  default_scope { where('packages.project_id not in (?)', Relationship.forbidden_project_ids) }

  scope :dirty_backend_package, -> { joins('left outer join backend_packages on backend_packages.package_id = packages.id').where('backend_packages.package_id is null') }

  validates :name, presence: true, length: { maximum: 200 }
  validate :valid_name

  has_one :backend_package, foreign_key: :package_id, dependent: :destroy, inverse_of: :package
  has_one :token, foreign_key: :package_id, dependent: :destroy

  has_many :tokens, dependent: :destroy, inverse_of: :package

  class << self

    def check_access?(dbpkg=self)
      return false if dbpkg.nil?
      return false unless dbpkg.class == Package
      return Project.check_access?(dbpkg.project)
    end

    def check_cache(project, package, opts)
      @key = { 'get_by_project_and_name' => 1, package: package, opts: opts }

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
        return nil if Project.is_remote_project?(project)
        prj = Project.get_by_name(project)
      end
      raise UnknownObjectError, "#{project}/#{package}" unless prj
      prj
    end

    # returns an object of package or raises an exception
    # should be always used when a project is required
    # in case you don't access sources or build logs in any way use 
    # use_source: false to skip check for sourceaccess permissions
    # function returns a nil object in case the package is on remote instance
    def get_by_project_and_name(project, package, opts = {})
      opts = { use_source: true, follow_project_links: true }.merge(opts)

      pkg = check_cache(project, package, opts)
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

    def get_by_project_and_name!(project, package, opts = {})
      pkg = get_by_project_and_name(project, package, opts)
      raise UnknownObjectError, "#{project}/#{package}" unless pkg
      pkg
    end

    # to check existens of a project (local or remote)
    def exists_by_project_and_name(project, package, opts = {})
      opts = { follow_project_links: true, allow_remote_packages: false }.merge(opts)
      begin
        prj = Project.get_by_name(project)
      rescue Project::UnknownObjectError
        return false
      end
      unless prj.is_a? Project
        return opts[:allow_remote_packages] && self.exists_on_backend?(package, project)
      end
      prj.exists_package?(package, opts)
    end

    def exists_on_backend?(package, project)
      begin
        answer = Suse::Backend.get(Package.source_path(project, package))
        return true if answer
      rescue ActiveXML::Transport::Error
        # ignored
      end
      return false
    end

    def find_by_project_and_name(project, package)
      return Package.where(name: package.to_s, projects: { name: project }).includes(:project).first
    end

    def find_by_attribute_type(attrib_type, package=nil)
      # One sql statement is faster than a ruby loop
      # attribute match in package or project
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.package_id
      LEFT OUTER JOIN attribs attrprj ON pack.project_id = attrprj.project_id
      WHERE ( attr.attrib_type_id = ? or attrprj.attrib_type_id = ? )
      END_SQL

      if package
        sql += ' AND pack.name = ? GROUP by pack.id'
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += ' GROUP by pack.id'
      ret = Package.find_by_sql [sql, attrib_type.id.to_s, attrib_type.id.to_s]
      ret.each do |dbpkg|
        ret.delete(dbpkg) unless Package.check_access?(dbpkg)
      end
      return ret
    end

    def find_by_attribute_type_and_value(attrib_type, value, package=nil)
      # One sql statement is faster than a ruby loop
      sql =<<-END_SQL
      SELECT pack.*
      FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.package_id
      LEFT OUTER JOIN attrib_values val ON attr.id = val.attrib_id
      WHERE attr.attrib_type_id = ? AND val.value = ?
      END_SQL

      if package
        sql += ' AND pack.name = ?'
        ret = Package.find_by_sql [sql, attrib_type.id.to_s, value.to_s, package]
        ret.each do |dbpkg|
          ret.delete(dbpkg) unless Package.check_access?(dbpkg)
        end
        return ret
      end
      sql += ' GROUP by pack.id'
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
    return true if flags.find_by_flag_and_status 'lock', 'enable'
    return self.project.is_locked?
  end

  def check_write_access!(ignoreLock=nil)
    return if Rails.env.test? and User.current.nil? # for unit tests
    # test _product permissions if any other _product: subcontainer is used
    obj = self
    obj = self.project.packages.where(:name => "_product").first if self.name =~ /\A_product:\w[-+\w\.]*\z/
    unless User.current.can_modify_package? obj, ignoreLock
      raise WritePermissionError, "No permission to modify package '#{self.name}' for user '#{User.current.login}'"
    end
  end

  # NOTE: this is no permission check, should it be added ?
  def can_be_deleted?
    # check if other packages have me as devel package
    msg = ''
    packs = []
    self.develpackages.each do |dpkg|
      msg += dpkg.project.name + '/' + dpkg.name + ', '
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
    path += ')'
    answer = Suse::Backend.post path, nil
    data = REXML::Document.new(answer.body)
    result = []

    data.elements.each('collection/package') do |e|
      p = Package.find_by_project_and_name(e.attributes['project'], e.attributes['name'])
      if p.nil?
        logger.error "read permission or data inconsistency, backend delivered package as linked package where no database object exists: #{e.attributes['project']} / #{e.attributes['name']}"
      else
        result.push(p)
      end
    end

    return result
  end

  def check_for_product
    if name == '_product'
      project.update_product_autopackages
    end
  end

  before_destroy :check_for_product

  def private_set_package_kind(dir)
    kinds = detect_package_kinds(dir)

    self.package_kinds.each do |pk|
      if kinds.include? pk.kind
        kinds.delete(pk.kind)
      else
        pk.delete
      end
    end
    kinds.each do |k|
      self.package_kinds.create :kind => k
    end
  end

  def sources_changed(dir_xml = nil)
    update_activity
    # mark the backend infos "dirty"
    BackendPackage.where(package_id: self.id).delete_all
    if dir_xml
      dir_xml = dir_xml.body if dir_xml.is_a? Net::HTTPSuccess
    else
      dir_xml = source_file(nil)
    end
    private_set_package_kind Xmlhash.parse(dir_xml)
    check_for_product
    # now trigger a delayed job
    self.delay.update_if_dirty
  end

  def self.source_path(project, package, file = nil, opts = {})
    path = "/source/#{URI.escape(project)}/#{URI.escape(package)}"
    path += "/#{URI.escape(file)}" unless file.blank?
    path += '?' + opts.to_query unless opts.blank?
    path
  end

  def source_path(file = nil, opts = {})
    Package.source_path(self.project.name, self.name, file, opts)
  end

  def source_file(file, opts = {})
    Suse::Backend.get(source_path(file, opts)).body
  end

  def self.dir_hash(project, package, opts = {})
    begin
      directory = Suse::Backend.get(source_path(project, package, nil, opts)).body
      Xmlhash.parse(directory)
    rescue ActiveXML::Transport::Error => e
      Xmlhash::XMLHash.new error: e.summary
    end
  end

  def dir_hash(opts = {})
    Package.dir_hash(self.project.name, self.name, opts)
  end

  def is_patchinfo?
    is_of_kind? :patchinfo
  end

  def is_link?
    is_of_kind? :link
  end

  def is_channel?
    is_of_kind? :channel
  end

  def is_product?
    is_of_kind? :product
  end

  def is_of_kind? kind
    self.package_kinds.where(kind: kind).exists?
  end

  def update_issue_list
    current_issues = []
    if self.is_patchinfo?
      xml = Patchinfo.new.read_patchinfo_xmlhash(self)
      xml.elements('issue') do |i|
        begin
          current_issues << [ Issue.find_or_create_by_name_and_tracker(i['id'], i['tracker']) ,'kept' ]
        rescue IssueTracker::NotFoundError => e
          # if the issue is invalid, we ignore it
          Rails.logger.debug e
        end
      end
    else
      # onlyissues backend call gets the issues from .changes files
      current_issues = find_changed_issues
    end

    # hash existing entries
    pis = Hash.new
    self.package_issues.each { |pi| pis[pi.issue.label] = pi }

    # new/update issue entries
    current_issues.each do |issue, change|
      if pi = pis[issue.label] 
        # issue exists already for this package
        unless pi.change == change
          # update state
          pi.change = change
          pi.save!
        end
        # entry exists already in correct way, do not drop it
        pis.delete(issue.label)
      else
        # new entry
        self.package_issues.create(issue: issue, change: change)
      end
    end

    # drop old entries
    self.package_issues.delete(pis.values)
  end

  def parse_issues_xml(query)
    begin
      issues = Suse::Backend.post(self.source_path(nil, query), nil)
      xml = Xmlhash.parse(issues.body)
      xml.get('issues').elements('issue') do |i|
        issue = Issue.find_or_create_by_name_and_tracker(i['name'], i['tracker'])
        yield issue, i['state']
      end
    rescue ActiveXML::Transport::Error => e
      Rails.logger.debug "failed to parse issues: #{e.inspect}"
    end
  end

  def find_changed_issues
    issue_change={}
    # no expand=1, so only branches are tracked
    query = { cmd: :diff, orev: 0, onlyissues: 1, linkrev: :base, view: :xml }
    parse_issues_xml(query) do |issue, state|
      issue_change[issue] = 'kept'
    end

    # issues introduced by local changes
    return issue_change unless self.is_link?
    query = { cmd: :linkdiff, onlyissues: 1, linkrev: :base, view: :xml }
    parse_issues_xml(query) do |issue, state|
      issue_change[issue] = state
    end

    issue_change
  end

  def update_channel_list
    Channel.transaction do
      self.channels.destroy_all
      if self.is_channel?
        xml = Suse::Backend.get(self.source_path('_channel'))
        channel = self.channels.create
        channel.update_from_xml(xml.body.to_s)
      end
    end
  end

  def update_product_list
    unless self.is_product?
      self.products.destroy_all
      return
    end
    Product.transaction do
      begin
        xml = Xmlhash.parse(Suse::Backend.get(self.source_path(nil, view: :products)).body)
      rescue ActiveXML::Transport::Error
        return # do not touch
      end
      self.products.destroy_all
      xml.elements('productdefinition') do |pd|
        # we are either an operating system or an application for CPE
        swClass = "o"
        pd.elements("mediasets") do |ms|
          ms.elements("media") do |m|
            # product depends on others, so it is no standalone operating system
            swClass = "a" if m.elements("productdependency").length > 0
          end
        end
        pd.elements('products') do |ps|
          ps.elements('product') do |p|
            product = Product.find_or_create_by_name_and_package(p['name'], self)
            unless version = p['version']
              version = "#{p['baseversion']}.#{p['patchlevel']}"
            end
            product.set_CPE(swClass, p['vendor'], version)
            product.save!
          end
        end
      end
    end
  end

  def detect_package_kinds(directory)
    raise ArgumentError.new 'neh!' if  directory.has_key? 'time'
    ret = []
    directory.elements('entry') do |e|
      %w{patchinfo aggregate link channel}.each do |kind|
        if e['name'] == '_' + kind
          ret << kind
        end
      end
      if e['name'] =~ /.product$/
        ret << 'product'
      end
      # further types my be spec, dsc, kiwi in future
    end
    ret
  end

  def resolve_devel_package
    pkg = self
    prj_name = pkg.project.name
    processed = {}

    if pkg == pkg.develpackage
      raise CycleError.new 'Package defines itself as devel package'
    end
    while (pkg.develpackage or pkg.project.develproject)
      #logger.debug "resolve_devel_package #{pkg.inspect}"

      # cycle detection
      str = prj_name+'/'+pkg.name
      if processed[str]
        processed.keys.each do |key|
          str = str + ' -- ' + key
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

  def update_from_xml(xmlhash)
    check_write_access!

    Package.transaction do

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

      update_relationships_from_xml(xmlhash)

      #---begin enable / disable flags ---#
      update_all_flags(xmlhash)

      #--- update url ---#
      self.url = xmlhash.value('url')
      #--- end update url ---#

      save!
    end
  end

  # for the HasAttributes mixing
  def attribute_url
    self.source_path('_attribute')
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
      query = { user: User.current ? User.current.login : '_nobody_' }
      query[:comment] = @commit_opts[:comment] unless @commit_opts[:comment].blank?
      Suse::Backend.put_source(self.source_path('_meta', query), to_axml)
    end
    @commit_opts = {}
  end

  def to_axml_id
    return "<package project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>"
  end

  def to_axml
    Rails.cache.fetch('xml_package_%d' % self.id) do
      # CanRenderModel
      render_xml
    end
  end

  def self.activity_algorithm
    # this is the algorithm (sql) we use for calculating activity of packages
    # we use Time.now.to_i instead of UNIX_TIMESTAMP() so we can test with frozen ruby time
    '( packages.activity_index * ' +
        "POWER( 2.3276, (UNIX_TIMESTAMP(packages.updated_at) - #{Time.now.to_i})/10000000 ) " +
        ') as activity_value'
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
    new_activity = activity + addon
    new_activity = 100 if new_activity > 100

    # rails 3 only - rails 4 is reported to name it update_columns
    self.update_column(:activity_index, new_activity)
    # we need to update the timestamp manually to avoid the activity_algorithm to run away
    self.update_column(:updated_at, Time.now)
    # just for beauty - and only saved if we save it for other reasons
    self.update_counter += 1
  end

  def expand_flags
    return project.expand_flags(self)
  end

  def open_requests_with_package_as_source_or_target
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    rel = rel.where('(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?) or (bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)', self.project.name, self.name, self.project.name, self.name)
    return BsRequest.where(id: rel.select('bs_requests.id').map { |r| r.id })
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", self.project.name, self.name)
    return BsRequest.where(id: rel.select('bs_requests.id').map { |r| r.id })
  end

  def linkinfo
    dir_hash['linkinfo']
  end

  def rev
    dir_hash['rev']
  end

  def channels
    update_if_dirty
    super
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
    parent = nil
    ChannelBinary.find_by_project_and_package(project_name, package_name).each do |cb|
      parent ||= self.project.find_parent
      cb.create_channel_package(self, parent)
    end
    self.project.store
  end

  def developed_packages
    packages = []
    candidates = Package.where(develpackage_id: self).load
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
    if name =~ %r{^[_\.]} && !%w(_product _pattern _project _patchinfo).include?(name)
      return false
    end
    return name =~ /\A\w[-+\w\.]*\z/
  end

  def valid_name
    errors.add(:name, 'is illegal') unless Package.valid_name?(self.name)
  end

  def branch_from(origin_project, origin_package, rev=nil, missingok=nil, comment=nil)
    myparam = { :cmd => 'branch',
                :noservice => '1',
                :oproject => origin_project,
                :opackage => origin_package,
                :user => User.current.login,
    }
    myparam[:orev] = rev if rev and not rev.empty?
    myparam[:missingok] = '1' if missingok
    myparam[:comment] = comment if comment
    path = self.source_path + Suse::Backend.build_query_from_hash(myparam, [:cmd, :oproject, :opackage, :user, :comment, :orev, :missingok])
    # branch sources in backend
    Suse::Backend.post path, nil
  end

  # just make sure the backend_package is there
  def update_if_dirty
    self.backend_package
  end

  def linking_packages
    ::Package.joins(:backend_package).where(backend_packages: { links_to_id: self.id })
  end

  def backend_package
    bp = super
    # if it's there, it's supposed to be fine
    return bp if bp
    update_backendinfo
  end

  def update_backendinfo
    bp = build_backend_package

    # determine the infos provided by srcsrv
    dir = self.dir_hash(view: :info, withchangesmd5: 1, nofilename: 1)
    bp.verifymd5 = dir['verifymd5']
    bp.changesmd5 = dir['changesmd5']
    bp.expandedmd5 = dir['srcmd5']
    if dir['revtime'].blank? # no commit, no revtime
      bp.maxmtime = nil
    else
      bp.maxmtime = Time.at(Integer(dir['revtime']))
    end

    # now check the unexpanded sources
    update_backendinfo_unexpanded(bp)

    # track defined products in _product containers
    update_product_list

    # update channel information
    update_channel_list

    # update issue database based on file content
    update_issue_list

    begin
      bp.save
    rescue ActiveRecord::RecordNotUnique
      # it's not too unlikely that another process tried to save the same infos
      # we can ignore the problem - the other process will have gathered the
      # same infos.
    end
    bp
  end

  def update_backendinfo_unexpanded(bp)
    dir = self.dir_hash

    bp.srcmd5 = dir['srcmd5']
    li = dir['linkinfo']
    if li
      bp.error = li['error']

      Rails.logger.debug "Syncing link #{self.project.name}/#{self.name} -> #{li['project']}/#{li['package']}"
      # we have to be careful - the link target can be nowhere
      bp.links_to = Package.find_by_project_and_name(li['project'], li['package'])
    else
      bp.error = nil
      bp.links_to = nil
    end
  end

  def comment_class
    CommentPackage
  end

  def delete_cache_lines
    CacheLine.cleanup_package(self.project.name, self.name)
  end

  def remove_linked_packages
    BackendPackage.where(links_to_id: self.id).delete_all
  end

  def patchinfo
    begin
      Patchinfo.new(self.source_file('_patchinfo'))
    rescue ActiveXML::Transport::NotFoundError
      nil
    end
  end

  def delete_file(name, opt = {})
    delete_opt = Hash.new
    delete_opt[:keeplink] = 1 if opt[:expand]
    delete_opt[:user] = User.current.login
    delete_opt[:comment] = opt[:comment] if opt[:comment]

    unless User.current.can_modify_package? self
      raise DeleteFileNoPermission.new 'Insufficient permissions to delete file'
    end

    Suse::Backend.delete self.source_path(name, delete_opt)
    sources_changed
  end

  def enable_for_repository repoName 
    update_needed = nil
    if self.project.flags.find_by_flag_and_status( 'build', 'disable' )
      # enable package builds if project default is disabled
      self.flags.create( :position => 1, :flag => 'build', :status => 'enable', :repo => repoName )
      update_needed = true
    end
    if self.project.flags.find_by_flag_and_status( 'debuginfo', 'disable' )
      # take over debuginfo config from origin project
      self.flags.create( :position => 1, :flag => 'debuginfo', :status => 'enable', :repo => repoName )
      update_needed = true
    end
    self.store if update_needed
  end

  BINARY_EXTENSIONS = %w{.0 .bin .bin_mid .bz .bz2 .ccf .cert .chk .der .dll .exe .fw .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .otf .oxt .pdf .pk3 .png .ps .rpm .sig .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .ucode .xpm .xz .z .zip .ttf}

  def self.is_binary_file?(filename)
    BINARY_EXTENSIONS.include?(File.extname(filename).downcase)
  end

  def serviceinfo
    unless @serviceinfo
      begin
        dir = Directory.find( project: project.name, :package => name)
        @serviceinfo = dir.find_first(:serviceinfo) if dir
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @serviceinfo
  end

  def parse_all_history
    answer = source_file('_history')

    doc = Xmlhash.parse(answer)
    doc.elements('revision') do |s|
      Rails.cache.write(['history', self, s['rev']], s)
    end
  end

  def commit( rev = nil )
    if rev and rev.to_i < 0
      # going backward from not yet known current revision, find out ...
      r = self.rev.to_i + rev.to_i + 1
      rev = r.to_s
      return nil if rev.to_i < 1
    end
    rev ||= self.rev

    cache_key = ['history', self, rev]
    c = Rails.cache.read(cache_key)
    return c if c

    parse_all_history
    # now it has to be in cache
    Rails.cache.read(cache_key)
  end

  def save_file(opt = {})
    content = '' # touch an empty file first
    content = opt[:file] if opt[:file]
    logger.debug "storing file: filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    put_opt = {}
    put_opt[:comment] = opt[:comment] if opt[:comment]
    put_opt[:user] = User.current.login

    path = self.source_path(opt[:filename], put_opt)
    ActiveXML::backend.http_do :put, path, data: content, timeout: 500
  end

  def to_param
    name
  end

  def to_s
    name
  end

  def fixtures_name
    "#{project.name}_#{name}".gsub(':', '_')
  end

  def api_obj
    self
  end
end
