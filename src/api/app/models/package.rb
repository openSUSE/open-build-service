# -*- encoding: utf-8 i*-
require_dependency 'api_exception'
require 'builder/xchar'
require 'rexml/document'
require_dependency 'has_relationships'
require_dependency 'opensuse/validator'

class Package < ApplicationRecord
  include FlagHelper
  include CanRenderModel
  include ForbidsAnonymousUsers
  include HasRelationships
  has_many :relationships, dependent: :destroy, inverse_of: :package

  include HasRatings
  include HasAttributes

  class PackageError < StandardError; end

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
  class UnknownObjectError < APIException
    setup 'unknown_package', 404, 'Unknown package'
  end
  class ReadAccessError < UnknownObjectError; end
  class ReadSourceAccessError < APIException
    setup 'source_access_no_permission', 403, 'Source Access not allowed'
  end
  class IllegalFileName < APIException; setup 'invalid_file_name_error'; end
  class PutFileNoPermission < APIException; setup 403; end

  belongs_to :project, inverse_of: :packages
  delegate :name, to: :project, prefix: true
  delegate :repositories, to: :project
  delegate :architectures, to: :project

  attr_reader :commit_opts
  attr_writer :commit_opts
  after_initialize do
    @commit_opts = {}
  end

  has_many :messages, as: :db_object, dependent: :delete_all

  has_many :taggings, as: :taggable, dependent: :delete_all
  has_many :tags, through: :taggings

  has_many :flags, -> { order(:position) }, dependent: :delete_all, inverse_of: :package

  belongs_to :develpackage, class_name: 'Package', foreign_key: 'develpackage_id'
  has_many :develpackages, class_name: 'Package', foreign_key: 'develpackage_id'

  has_many :attribs, dependent: :destroy, foreign_key: :package_id

  has_many :package_kinds, dependent: :delete_all
  has_many :package_issues, dependent: :delete_all # defined in sources
  has_many :issues, through: :package_issues

  has_many :products, dependent: :destroy
  has_many :channels, dependent: :destroy, foreign_key: :package_id

  has_many :comments, dependent: :destroy, inverse_of: :package, class_name: 'CommentPackage'

  has_many :binary_releases, dependent: :delete_all, foreign_key: 'release_package_id'

  before_destroy :delete_on_backend
  before_destroy :close_requests
  before_destroy :update_project_for_product
  before_destroy :remove_linked_packages
  before_destroy :remove_devel_packages

  after_destroy :delete_cache_lines

  after_save :write_to_backend
  before_update :update_activity
  after_rollback :reset_cache

  # The default scope is necessary to exclude the forbidden projects.
  # It's necessary to write it as a nested Active Record query for performance reasons
  # which will produce a query like:
  # WHERE (`packages`.`id` NOT IN (SELECT `packages`.`id` FROM `packages` WHERE packages.project_id in (0))
  # This is faster than
  # default_scope { where('packages.project_id not in (?)', Relationship.forbidden_project_ids) }
  # which would produce a query like
  # WHERE (packages.project_id not in (0))
  # because we assumes that there are more allowed projects than forbidden ones.
  default_scope {
    where.not(id: Package.where(project_id: Relationship.forbidden_project_ids))
  }

  scope :order_by_name, -> { order('LOWER(name)') }

  # rubocop:disable Metrics/LineLength
  scope :dirty_backend_package, -> { joins('left outer join backend_packages on backend_packages.package_id = packages.id').where('backend_packages.package_id is null') }
  # rubocop:enable Metrics/LineLength

  validates :name, presence: true, length: { maximum: 200 }
  validates :releasename, length: { maximum: 200 }
  validates :title, length: { maximum: 250 }
  validate :valid_name

  has_one :backend_package, foreign_key: :package_id, dependent: :destroy, inverse_of: :package
  has_one :token, foreign_key: :package_id, dependent: :destroy

  has_many :tokens, dependent: :destroy, inverse_of: :package

  def self.check_access?(dbpkg = self)
    return false if dbpkg.nil?
    return false unless dbpkg.class == Package
    return Project.check_access?(dbpkg.project)
  end

  def self.check_cache(project, package, opts)
    @key = { 'get_by_project_and_name' => 1, :package => package, :opts => opts }

    @key[:user] = User.current.cache_key if User.current

    # the cache is only valid if the user, prj and pkg didn't change
    if project.is_a? Project
      @key[:project] = project.id
    else
      @key[:project] = project
    end
    pid, old_pkg_time, old_prj_time = Rails.cache.read(@key)
    if pid
      pkg=Package.where(id: pid).includes(:project).first
      return pkg if pkg && pkg.updated_at == old_pkg_time && pkg.project.updated_at == old_prj_time
      Rails.cache.delete(@key) # outdated anyway
    end
    return nil
  end

  def self.internal_get_project(project)
    if project.is_a? Project
      prj = project
    else
      return nil if Project.is_remote_project?(project)
      prj = Project.get_by_name(project)
    end
    raise UnknownObjectError, "#{project}/#{package}" unless prj
    prj
  end

  def self.striping_multibuild_suffix(name)
    # exception for package names used to have a collon
    return name if name.start_with?("_patchinfo:", "_product:")

    name.gsub(/:.*$/, '')
  end

  # returns an object of package or raises an exception
  # should be always used when a project is required
  # in case you don't access sources or build logs in any way use
  # use_source: false to skip check for sourceaccess permissions
  # function returns a nil object in case the package is on remote instance
  def self.get_by_project_and_name(project, package, opts = {})
    opts = { use_source: true, follow_project_links: true,
             follow_multibuild: false, check_update_project: false }.merge(opts)

    package = striping_multibuild_suffix(package) if opts[:follow_multibuild]

    pkg = check_cache(project, package, opts)
    return pkg if pkg

    prj = internal_get_project(project)
    return nil unless prj # remote prjs

    if pkg.nil? && opts[:follow_project_links]
      pkg = prj.find_package(package, opts[:check_update_project])
    elsif pkg.nil?
      pkg = prj.update_instance.packages.find_by_name(package) if opts[:check_update_project]
      pkg = prj.packages.find_by_name(package) if pkg.nil?
    end

    if pkg.nil? && opts[:follow_project_links]
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
    pkg
  end

  def self.get_by_project_and_name!(project, package, opts = {})
    pkg = get_by_project_and_name(project, package, opts)
    raise UnknownObjectError, "#{project}/#{package}" unless pkg
    pkg
  end

  # to check existens of a project (local or remote)
  def self.exists_by_project_and_name(project, package, opts = {})
    opts = { follow_project_links: true, allow_remote_packages: false }.merge(opts)
    begin
      prj = Project.get_by_name(project)
    rescue Project::UnknownObjectError
      return false
    end
    unless prj.is_a? Project
      return opts[:allow_remote_packages] && exists_on_backend?(package, project)
    end
    prj.exists_package?(package, opts)
  end

  def self.exists_on_backend?(package, project)
    begin
      answer = Suse::Backend.get(Package.source_path(project, package))
      return true if answer
    rescue ActiveXML::Transport::Error
      # ignored
    end
    false
  end

  def self.find_by_project_and_name(project, package)
    Package.where(name: package.to_s, projects: { name: project }).includes(:project).first
  end

  def self.find_by_attribute_type(attrib_type, package = nil)
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
    ret
  end

  def self.find_by_attribute_type_and_value(attrib_type, value, package = nil)
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
    ret
  end

  def check_source_access?
    if disabled_for?('sourceaccess', nil, nil) || project.disabled_for?('sourceaccess', nil, nil)
      unless User.current && User.current.can_source_access?(self)
        return false
      end
    end
    return true
  end

  def check_source_access!
    if !check_source_access?
      be_not_nobody!
      raise ReadSourceAccessError, "#{project.name}/#{name}"
    end
  end

  def is_locked?
    return true if flags.find_by_flag_and_status 'lock', 'enable'
    return project.is_locked?
  end

  def check_write_access(ignoreLock = nil)
    # test _product permissions if any other _product: subcontainer is used
    obj = self
    obj = project.packages.find_by(name: "_product") if name =~ /\A_product:\w[-+\w\.]*\z/
    return true if User.current.can_modify_package? obj, ignoreLock
    false
  end

  def check_write_access!(ignoreLock = nil)
    return if Rails.env.test? && User.current.nil? # for unit tests
    unless check_write_access(ignoreLock)
      raise WritePermissionError, "No permission to modify package '#{name}' for user '#{User.current.login}'"
    end
  end

  def check_weak_dependencies?
    develpackages.each do |package|
      errors.add(:base, "used as devel package by #{package.project.name}/#{package.name}")
    end
    return false if errors.any?
    true
  end

  def check_weak_dependencies!(ignore_local = false)
    # check if other packages have me as devel package
    packs = develpackages
    packs = packs.where.not(project: project) if ignore_local
    packs = packs.to_a
    unless packs.empty?
      msg = packs.map { |p| p.project.name + '/' + p.name }.join(', ')
      de = DeleteError.new "Package is used by following packages as devel package: #{msg}"
      de.packages = packs
      raise de
    end
  end

  def find_project_local_linking_packages
    find_linking_packages(1)
  end

  def find_linking_packages(project_local = nil)
    path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(name)}\"+and+linkinfo/@project=\"#{CGI.escape(project.name)}\""
    path += "+and+@project=\"#{CGI.escape(project.name)}\"" if project_local
    path += ')'
    answer = Suse::Backend.post path
    data = REXML::Document.new(answer.body)
    result = []
    data.elements.each('collection/package') do |e|
      p = Package.find_by_project_and_name(e.attributes['project'], e.attributes['name'])
      if p.nil?
        logger.error "read permission or data inconsistency, backend delivered package as linked package " +
                     "where no database object exists: #{e.attributes['project']} / #{e.attributes['name']}"
      else
        result << p
      end
    end
    result
  end

  def update_project_for_product
    if name == '_product'
      project.update_product_autopackages
    end
  end

  def private_set_package_kind(dir)
    kinds = Package.detect_package_kinds(dir)

    package_kinds.each do |pk|
      if kinds.include? pk.kind
        kinds.delete(pk.kind)
      else
        pk.delete
      end
    end
    kinds.each do |k|
      package_kinds.create kind: k
    end
  end

  def unlock_by_request(request)
    f = flags.find_by_flag_and_status('lock', 'enable')
    if f
      flags.delete(f)
      store(comment: "Request got revoked", request: request, lowprio: 1)
    end
  end

  def sources_changed(opts = {})
    dir_xml = opts[:dir_xml]
    update_activity
    # mark the backend infos "dirty"
    BackendPackage.where(package_id: id).delete_all
    if dir_xml.is_a? Net::HTTPSuccess
      dir_xml = dir_xml.body
    else
      dir_xml = source_file(nil)
    end
    private_set_package_kind Xmlhash.parse(dir_xml)
    update_project_for_product
    if opts[:wait_for_update]
      update_if_dirty
    else
      retries=10
      begin
        delay.update_if_dirty
      rescue ActiveRecord::StatementInvalid
        # mysql lock errors in delayed job handling... we need to retry
        retries = retries - 1
        retry if retries > 0
      end
    end
  end

  def self.source_path(project, package, file = nil, opts = {})
    path = "/source/#{URI.escape(project)}/#{URI.escape(package)}"
    path += "/#{URI.escape(file)}" unless file.blank?
    path += '?' + opts.to_query unless opts.blank?
    path
  end

  def source_path(file = nil, opts = {})
    Package.source_path(project.name, name, file, opts)
  end

  def source_file(file, opts = {})
    Suse::Backend.get(source_path(file, opts)).body
  end

  # Reads the source file and converts it into an ActiveXML::Node
  def source_file_to_axml(file, opts = {})
    ActiveXML::Node.new(source_file(file, opts))
  end

  def dir_hash(opts = {})
    Directory.hashed(opts.update(project: project.name, package: name))
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
    package_kinds.where(kind: kind).exists?
  end

  def update_issue_list
    current_issues = {}
    if is_patchinfo?
      xml = Patchinfo.new.read_patchinfo_xmlhash(self)
      xml.elements('issue') do |i|
        begin
          current_issues['kept'] ||= []
          current_issues['kept'] << Issue.find_or_create_by_name_and_tracker(i['id'], i['tracker'])
        rescue IssueTracker::NotFoundError => e
          # if the issue is invalid, we ignore it
          Rails.logger.debug e
        end
      end
    else
      # onlyissues backend call gets the issues from .changes files
      current_issues = find_changed_issues
    end

    # fast sync our relations
    PackageIssue.sync_relations(self, current_issues)
  end

  def parse_issues_xml(query, force_state = nil)
    begin
      answer = Suse::Backend.post(source_path(nil, query))
    rescue ActiveXML::Transport::Error => e
      Rails.logger.debug "failed to parse issues: #{e.inspect}"
      return {}
    end
    xml = Xmlhash.parse(answer.body)

    # collect all issues and put them into an hash
    issues = {}
    xml.get('issues').elements('issue') do |i|
      issues[i['tracker']] ||= {}
      issues[i['tracker']][i['name']] = force_state || i['state']
    end

    issues
  end

  def find_changed_issues
    # no expand=1, so only branches are tracked
    query = { cmd: :diff, orev: 0, onlyissues: 1, linkrev: :base, view: :xml }
    issue_change = parse_issues_xml(query, 'kept')
    # issues introduced by local changes
    if is_link?
      query = { cmd: :linkdiff, onlyissues: 1, linkrev: :base, view: :xml }
      new = parse_issues_xml(query)
      (issue_change.keys + new.keys).uniq.each do |key|
        issue_change[key] ||= {}
        issue_change[key].merge!(new[key]) if new[key]
        issue_change['kept'].delete(new[key]) if issue_change['kept'] && key != 'kept'
      end
    end

    myissues = {}
    Issue.transaction do
      # update existing issues
      issues.each do |issue|
        next unless issue_change[issue.issue_tracker.name]
        next unless issue_change[issue.issue_tracker.name][issue.name]
        state = issue_change[issue.issue_tracker.name][issue.name]
        myissues[state] ||= []
        myissues[state] << issue
        issue_change[issue.issue_tracker.name].delete(issue.name)
      end

      issue_change.keys.each do |tracker|
        t=IssueTracker.find_by_name tracker

        # create new issues
        issue_change[tracker].keys.each do |name|
          issue = t.issues.find_by_name(name) || t.issues.create(name: name)
          state = issue_change[tracker][name]
          myissues[state] ||= []
          myissues[state] << issue
        end
      end
    end

    myissues
  end

  def update_channel_list
    if is_channel?
      xml = Suse::Backend.get(source_path('_channel'))
      begin
        channels.first_or_create.update_from_xml(xml.body.to_s)
      rescue ActiveRecord::RecordInvalid => e
        if Rails.env.test?
          raise e
        else
          HoptoadNotifier.notify(e, { failed_job: "Couldn't store channel" })
        end
      end
    else
      channels.destroy_all
    end
  end

  def update_product_list
    # short cut to ensure that no products are left over
    unless is_product?
      products.destroy_all
      return
    end

    # hash existing entries
    old = Hash.new
    products.each { |p| old[p.name] = p }

    Product.transaction do
      begin
        xml = Xmlhash.parse(Suse::Backend.get(source_path(nil, view: :products)).body)
      rescue
        return
      end
      xml.elements('productdefinition') do |pd|
        pd.elements('products') do |ps|
          ps.elements('product') do |p|
            product = Product.find_or_create_by_name_and_package(p['name'], self)
            product = product.first unless product.class == Product
            product.update_from_xml(xml)
            product.save!
            old.delete(product.name)
          end
        end
      end

      # drop old entries
      products.destroy(old.values)
    end
  end

  def self.detect_package_kinds(directory)
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
    ret.uniq
  end

  # delivers only a defined devel package
  def find_devel_package
     pkg = resolve_devel_package
     return nil if pkg == self
     pkg
  end

  # delivers always a package
  def resolve_devel_package
    pkg = self
    prj_name = pkg.project.name
    processed = {}

    if pkg == pkg.develpackage
      raise CycleError.new 'Package defines itself as devel package'
    end
    while (pkg.develpackage || pkg.project.develproject)
      # logger.debug "resolve_devel_package #{pkg.inspect}"

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
      if pkg.id == id
        pkg = self
      end
    end
    # logger.debug "WORKED - #{pkg.inspect}"
    return pkg
  end

  def update_from_xml(xmlhash, ignoreLock = nil)
    check_write_access!(ignoreLock)

    Package.transaction do
      self.title = xmlhash.value('title')
      self.description = xmlhash.value('description')
      self.bcntsynctag = xmlhash.value('bcntsynctag')
      self.releasename = xmlhash.value('releasename')

      #--- devel project ---#
      self.develpackage = nil
      devel = xmlhash['devel']
      if devel
        prj_name = devel['project'] || xmlhash['project']
        pkg_name = devel['package'] || xmlhash['name']
        develprj = Project.find_by_name(prj_name)
        unless develprj
          raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
        end
        develpkg = develprj.packages.find_by_name(pkg_name)
        unless develpkg
          raise SaveError, "value of develpackage has to be a existing package (package '#{pkg_name}' does not exist)"
        end
        self.develpackage = develpkg
      end
      #--- end devel project ---#

      # just for cycle detection
      resolve_devel_package

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
    source_path('_attribute')
  end

  def store(opts = {})
    # no write access check here, since this operation may will disable this permission ...
    self.commit_opts = opts if opts
    save!
  end

  def reset_cache
    Rails.cache.delete("xml_package_#{id}") if id
  end

  def set_comment(comment)
    @commit_opts[:comment] = comment
  end

  def write_to_backend
    reset_cache
    #--- write through to backend ---#
    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      query = { user: User.current ? User.current.login : User.nobody_login }
      query[:comment] = @commit_opts[:comment] unless @commit_opts[:comment].blank?
      # the request number is the requestid parameter in the backend api
      query[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
      Suse::Backend.put_source(source_path('_meta', query), to_axml)
      logger.tagged('backend_sync') { logger.debug "Saved Package #{project.name}/#{name}" }
    else
      if @commit_opts[:no_backend_write]
        logger.tagged('backend_sync') { logger.warn "Not saving Package #{project.name}/#{name}, backend_write is off " }
      else
        logger.tagged('backend_sync') { logger.warn "Not saving Package #{project.name}/#{name}, global_write_through is off" }
      end
    end
    true
  end

  def delete_on_backend
    # lock this package object to avoid that dependend objects get created in parallel
    # for example a backend_package
    reload(lock: true)

    # not really packages...
    # everything below _product:
    return true if name =~ /\A_product:\w[-+\w\.]*\z/
    return true if name == '_project'

    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      path = source_path

      h = { user: User.current.login, comment: commit_opts[:comment] }
      h[:requestid] = commit_opts[:request].number if commit_opts[:request]
      path << Suse::Backend.build_query_from_hash(h, [:user, :comment, :requestid])
      begin
        Suse::Backend.delete path
      rescue ActiveXML::Transport::NotFoundError
        # ignore this error, backend was out of sync
        logger.tagged('backend_sync') { logger.warn("Package #{project.name}/#{name} was already missing on backend on removal") }
      end
      logger.tagged('backend_sync') { logger.warn("Deleted Package #{project.name}/#{name}") }
    else
      if @commit_opts[:no_backend_write]
        unless @commit_opts[:project_destroy_transaction]
          logger.tagged('backend_sync') { logger.warn "Not deleting Package #{project.name}/#{name}, backend_write is off " }
        end
      else
        logger.tagged('backend_sync') { logger.warn "Not deleting Package #{project.name}/#{name}, global_write_through is off" }
      end
    end
    true
  end

  def to_axml_id
    return "<package project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  def to_axml(_opts = {})
    Rails.cache.fetch('xml_package_%d' % id) do
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
                                      "FROM `packages` WHERE id = #{id} LIMIT 1")
    return package.shift.activity_value.to_f
  end

  # is called before_update
  def update_activity
    # the value we add to the activity, when the object gets updated
    addon = 10 * (Time.now.to_f - updated_at_was.to_f) / 86400
    addon = 10 if addon > 10
    new_activity = activity + addon
    new_activity = 100 if new_activity > 100

    # rails 3 only - rails 4 is reported to name it update_columns
    update_column(:activity_index, new_activity)
    # we need to update the timestamp manually to avoid the activity_algorithm to run away
    update_column(:updated_at, Time.now)
    # just for beauty - and only saved if we save it for other reasons
    self.update_counter += 1
  end

  def expand_flags
    return project.expand_flags(self)
  end

  define_method :get_flags, GetFlags.instance_method(:get_flags)

  def open_requests_with_package_as_source_or_target
    rel = BsRequest.where(state: [:new, :review, :declined]).joins(:bs_request_actions)
    # rubocop:disable Metrics/LineLength
    rel = rel.where('(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?) or (bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)', project.name, name, project.name, name)
    # rubocop:enable Metrics/LineLength
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: [:new, :review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", project.name, name)
    return BsRequest.where(id: rel.pluck('bs_requests.id'))
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

  def services
    the_services = Service.find(project: project.name, package: name)
    the_services ||= Service.new(project: project.name, package: name)
    the_services
  end

  def build_result(repository, view = [])
    Buildresult.find(project: project, package: self, repository: repository, view: view)
  end

  # local mode (default): last package in link chain in my project
  # no local mode:        first package in link chain outside of my project
  def origin_container(options = { local: true })
    # link target package name is more important, since local name could be
    # extended. For example in maintenance incident projects.
    linkinfo = dir_hash['linkinfo']
    # no link, so I am origin
    return self if linkinfo.nil?

    if options[:local] && linkinfo['project'] != project.name
      # links to external project, so I am origin
      return self
    end

    # local link, go one step deeper
    prj = Project.get_by_name(linkinfo['project'])
    pkg = prj.find_package(linkinfo['package'])
    if !options[:local] && project != prj && !prj.is_maintenance_incident?
      return pkg
    end

    # If package is nil it's either broken or a remote one.
    # Otherwise we continue
    return pkg.try(:origin_container, options)
  end

  def is_local_link?
    linkinfo = dir_hash["linkinfo"]

    linkinfo && (linkinfo["project"] == project.name)
  end

  def modify_channel(mode = :add_disabled)
    raise InvalidParameterError unless [:add_disabled, :enable_all].include? mode
    channel = channels.first
    return unless channel
    channel.add_channel_repos_to_project(self, mode)
  end

  def add_channels(mode = :add_disabled)
    raise InvalidParameterError unless [:add_disabled, :skip_disabled, :enable_all].include? mode
    return if is_channel?

    opkg = origin_container(local: false)
    # remote or broken link?
    return if opkg.nil?

    # Update projects are usually used in _channels
    project_name = opkg.project.update_instance.name

    # not my link target, so it does not qualify for my code streastream
    return unless linkinfo && project_name == linkinfo['project']

    # main package
    name = opkg.name.dup
    # strip incident suffix in update release projects
    # but beware of packages where the name has already a dot
    name.gsub!(/\.[^\.]*$/, '') if opkg.project.is_maintenance_release? && !opkg.is_link?
    ChannelBinary.find_by_project_and_package(project_name, name).each do |cb|
      _add_channel(mode, cb, "Listed in #{project_name} #{name}")
    end
    # and all possible existing local links
    if opkg.project.is_maintenance_release? && opkg.is_link?
      opkg = opkg.project.packages.find_by_name opkg.linkinfo["package"]
    end

    opkg.find_project_local_linking_packages.each do |p|
      name = p.name
      # strip incident suffix in update release projects
      name.gsub!(/\.[^\.]*$/, '') if opkg.project.is_maintenance_release?
      ChannelBinary.find_by_project_and_package(project_name, name).each do |cb|
        _add_channel(mode, cb, "Listed in #{project_name} #{name}")
      end
    end
    project.store
  end

  def _add_channel(mode, channel_binary, message)
    # add source container
    return if mode == :skip_disabled && !channel_binary.channel_binary_list.channel.is_active?
    cpkg = channel_binary.create_channel_package_into(project, message)
    return unless cpkg
    # be sure that the object exists or a background job get launched
    cpkg.backend_package
    # add and enable repos
    return if mode == :add_disabled && !channel_binary.channel_binary_list.channel.is_active?
    cpkg.channels.first.add_channel_repos_to_project(cpkg, mode)
  end
  private :_add_channel

  def update_instance(namespace = 'OBS', name = 'UpdateProject')
    # check if a newer instance exists in a defined update project
    project.update_instance(namespace, name).find_package(self.name)
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
    return false if name == "0"
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
    errors.add(:name, 'is illegal') unless Package.valid_name?(name)
  end

  def branch_from(origin_project, origin_package, rev = nil, missingok = nil, comment = nil, olinkrev = nil)
    myparam = { cmd:       "branch",
                noservice: "1",
                oproject:  origin_project,
                opackage:  origin_package,
                user:      User.current.login
    }
    myparam[:orev] = rev if rev.present?
    myparam[:olinkrev] = olinkrev if olinkrev.present?
    myparam[:missingok] = '1' if missingok
    myparam[:comment] = comment if comment
    path = source_path
    path += Suse::Backend.build_query_from_hash(myparam, [:cmd, :oproject, :opackage, :user, :comment, :orev, :missingok, :olinkrev])
    # branch sources in backend
    Suse::Backend.post path
  end

  # just make sure the backend_package is there
  def update_if_dirty
    begin
      backend_package
    rescue Mysql2::Error
      # the delayed job might have jumped in and created the entry just before us
    end
  end

  def linking_packages
    ::Package.joins(:backend_package).where(backend_packages: { links_to_id: id })
  end

  def backend_package
    bp = super
    # if it's there, it's supposed to be fine
    return bp if bp
    update_backendinfo
  end

  def update_backendinfo
    # avoid creation of backend_package while destroying this package object
    reload(lock: true)

    bp = build_backend_package

    # determine the infos provided by srcsrv
    dir = dir_hash(view: :info, withchangesmd5: 1, nofilename: 1)
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
    dir = dir_hash

    bp.srcmd5 = dir['srcmd5']
    li = dir['linkinfo']
    if li
      bp.error = li['error']

      Rails.logger.debug "Syncing link #{project.name}/#{name} -> #{li['project']}/#{li['package']}"
      # we have to be careful - the link target can be nowhere
      bp.links_to = Package.find_by_project_and_name(li['project'], li['package'])
    else
      bp.error = nil
      bp.links_to = nil
    end
  end

  def delete_cache_lines
    CacheLine.cleanup_package(project.name, name)
  end

  def remove_linked_packages
    BackendPackage.where(links_to_id: id).delete_all
  end

  def remove_devel_packages
    Package.where(develpackage: self).each do |devel_package|
      devel_package.develpackage = nil
      devel_package.store
      devel_package.reset_cache
    end
  end

  def close_requests
    # Find open requests involving self and:
    # - revoke them if self is source
    # - decline if self is target
    open_requests_with_package_as_source_or_target.each do |request|
      logger.debug "#{self.class} #{name} doing close_requests on request #{request.id} with #{@commit_opts.inspect}"
      # Don't alter the request that is the trigger of this close_requests run
      next if request == @commit_opts[:request]

      request.bs_request_actions.each do |action|
        if action.source_project == project.name && action.source_package == name
          begin
            request.change_state({newstate: 'revoked', comment: "The source package '#{name}' has been removed"})
          rescue PostRequestNoPermission
            logger.debug "#{User.current.login} tried to revoke request #{id} but had no permissions"
          end
          break
        end
        if action.target_project == project.name && action.target_package == name
          begin
            request.change_state({newstate: 'declined', comment: "The target package '#{name}' has been removed"})
          rescue PostRequestNoPermission
            logger.debug "#{User.current.login} tried to decline request #{id} but had no permissions"
          end
          break
        end
      end
    end
    # Find open requests which have a review involving this package and remove those reviews
    # but leave the requests otherwise untouched.
    open_requests_with_by_package_review.each do |request|
      # Don't alter the request that is the trigger of this close_requests run
      next if request.id == @commit_opts[:request]

      request.obsolete_reviews(by_project: project.name, by_package: name)
    end
  end

  def patchinfo
    begin
      Patchinfo.new(source_file('_patchinfo'))
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

    Suse::Backend.delete source_path(name, delete_opt)
    sources_changed
  end

  def enable_for_repository repoName
    update_needed = nil
    if project.flags.find_by_flag_and_status( 'build', 'disable' )
      # enable package builds if project default is disabled
      flags.create( position: 1, flag: 'build', status: 'enable', repo: repoName )
      update_needed = true
    end
    if project.flags.find_by_flag_and_status( 'debuginfo', 'disable' )
      # take over debuginfo config from origin project
      flags.create( position: 1, flag: 'debuginfo', status: 'enable', repo: repoName )
      update_needed = true
    end
    store if update_needed
  end

  BINARY_EXTENSIONS = %w{.0 .bin .bin_mid .bz .bz2 .ccf .cert .chk .der .dll .exe .fw
                         .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .otf .oxt .pdf .pk3
                         .png .ps .rpm .sig .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz
                         .txz .ucode .xpm .xz .z .zip .ttf}

  def self.is_binary_file?(filename)
    BINARY_EXTENSIONS.include?(File.extname(filename).downcase)
  end

  def serviceinfo
    unless @serviceinfo
      begin
        dir = Directory.find( project: project.name, package: name)
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
    if rev && rev.to_i < 0
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

  def self.verify_file!(pkg, name, content)
    raise IllegalFileName, "'#{name}' is not a valid filename" if (!name.present? || !(name =~ %r{^[^\/]+$}))

    # file is an ActionDispatch::Http::UploadedFile and Suse::Validator.validate
    # will call to_s therefore we have to read the content first
    content = File.open(content.path).read if content.kind_of?(ActionDispatch::Http::UploadedFile)

    # schema validation, if possible
    %w{aggregate constraints link service patchinfo channel}.each do |schema|
      if name == '_' + schema
        Suse::Validator.validate(schema, content)
      end
    end

    # validate all files inside of _pattern container
    if pkg && pkg.name == "_pattern"
      Suse::Validator.validate('pattern', content)
    end

    # verify link
    if name == '_link'
      data = ActiveXML::Node.new(content)
      if data
        tproject_name = data.value('project') || pkg.project.name
        tpackage_name = data.value('package') || pkg.name
        if data.has_attribute? 'missingok'
          Project.get_by_name(tproject_name) # permission check
          if Package.exists_by_project_and_name(tproject_name, tpackage_name, follow_project_links: true, allow_remote_packages: true)
            raise NotMissingError.new "Link contains a missingok statement but link target (#{tproject_name}/#{tpackage_name}) exists."
          end
        else
          # permission check
          Package.get_by_project_and_name(tproject_name, tpackage_name)
        end
      end
    end

    # special checks in their models
    if name == '_service'
      Service.verify_xml!(content)
    end
    if name == '_channel'
      Channel.verify_xml!(content)
    end
    if name == '_patchinfo'
      Patchinfo.new.verify_data(pkg.project, content)
    end
    if name == '_attribute'
      raise IllegalFileName
    end
  end

  def save_file(opt = {})
    content = '' # touch an empty file first
    content = opt[:file] if opt[:file]

    logger.debug "storing file: filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    Package.verify_file!(self, opt[:filename], content)
    unless User.current.can_modify_package?(self)
      raise PutFileNoPermission, "Insufficient permissions to store file in package #{name}, project #{project.name}"
    end

    put_opt = {}
    put_opt[:comment] = opt[:comment] if opt[:comment]
    put_opt[:user] = User.current.login
    path = source_path(opt[:filename], put_opt)
    ActiveXML.backend.http_do :put, path, data: content, timeout: 500

    # KIWI file
    if opt[:filename] =~ /\.kiwi\.txz$/
      logger.debug 'Found a kiwi archive, creating kiwi_import source service'
      services = self.services
      services.addKiwiImport
    end

    # update package timestamp and reindex sources
    unless opt[:rev] == 'repository' || %w(_project _pattern).include?(name)
      sources_changed(wait_for_update: ['_aggregate', '_constraints', '_link', '_service', '_patchinfo', '_channel'].include?(opt[:filename]))
    end
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

  def rebuild(params)
    backend_build_command(:rebuild, params.slice(:package, :arch, :repository))
  end

  def wipe_binaries(params)
    backend_build_command(:wipe, params.slice(:package, :arch, :repository))
  end

  def abort_build(params)
    backend_build_command(:abortbuild, params.slice(:package, :arch, :repository))
  end

  def backend_build_command(command, params)
    begin
      # Note: This list needs to keep in sync with the backend code
      permitted_params = params.permit(:repository, :arch, :package, :code, :wipe)

      Suse::Backend.post("/build/#{URI.escape(project.name)}?cmd=#{command}&#{permitted_params.to_h.to_query}")
    rescue ActiveXML::Transport::Error, Timeout::Error => e
      errors.add(:base, e.message)
      return false
    end
    true
  end

  def file_exists?(filename)
    dir_hash.has_key?("entry") && [dir_hash["entry"]].flatten.any?{ |item| item["name"] == filename }
  end

  def has_icon?
    file_exists?("_icon")
  end
end
