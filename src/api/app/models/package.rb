require 'api_error'
require 'builder/xchar'
require 'rexml/document'

# rubocop: disable Metrics/ClassLength
class Package < ApplicationRecord
  include FlagHelper
  include FlagValidations
  include CanRenderModel
  include HasRelationships
  include Package::Errors
  include HasAttributes
  include PackageSphinx
  include MultibuildPackage
  include PackageMediumContainer
  include ReportBugUrl

  has_many :relationships, dependent: :destroy, inverse_of: :package
  belongs_to :kiwi_image, class_name: 'Kiwi::Image', inverse_of: :package, optional: true
  accepts_nested_attributes_for :kiwi_image

  belongs_to :project, inverse_of: :packages
  delegate :name, to: :project, prefix: true

  attr_accessor :commit_opts, :commit_user

  after_initialize do
    @commit_opts = {}
    # might be nil - in this case we rely on the caller to set it
    @commit_user = User.session
  end

  has_many :flags, -> { order(:position) }, dependent: :delete_all, inverse_of: :package

  belongs_to :develpackage, class_name: 'Package', optional: true
  has_many :develpackages, class_name: 'Package', foreign_key: 'develpackage_id'

  has_many :attribs, dependent: :destroy

  has_many :package_kinds, dependent: :delete_all
  has_many :package_issues, dependent: :delete_all # defined in sources
  has_many :issues, through: :package_issues

  has_many :products, dependent: :destroy
  has_many :channels, dependent: :destroy

  has_many :comments, as: :commentable, dependent: :destroy
  has_one :comment_lock, as: :commentable, dependent: :destroy

  has_many :binary_releases, dependent: :delete_all, foreign_key: 'release_package_id'

  has_many :reviews, dependent: :nullify

  has_many :target_of_bs_request_actions, class_name: 'BsRequestAction', foreign_key: 'target_package_id', dependent: :nullify
  has_many :target_of_bs_requests, through: :target_of_bs_request_actions, source: :bs_request

  has_many :source_of_bs_request_actions, class_name: 'BsRequestAction', foreign_key: 'source_package_id', dependent: :nullify
  has_many :source_of_bs_requests, through: :source_of_bs_request_actions, source: :bs_request

  has_many :event_subscription, dependent: :destroy

  has_many :watched_items, as: :watchable, dependent: :destroy
  has_many :reports, as: :reportable, dependent: :nullify
  has_many :labels, as: :labelable

  has_one :assignment, dependent: :destroy
  has_one :assignee, through: :assignment
  has_one :assigner, through: :assignment

  accepts_nested_attributes_for :labels, allow_destroy: true

  after_create :backfill_bs_request_actions

  before_update :update_activity
  after_update :convert_to_symsync

  before_destroy :delete_on_backend
  before_destroy :revoke_requests_with_self_as_source
  before_destroy :decline_requests_with_self_as_target
  before_destroy :obsolete_reviews_for_self
  before_destroy :update_project_for_product
  before_destroy :remove_linked_packages
  before_destroy :remove_devel_packages
  after_destroy :delete_from_sphinx

  after_save :write_to_backend
  after_save :populate_to_sphinx

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
  default_scope do
    where.not(id: PackagesFinder.new.forbidden_packages)
  end

  scope :order_by_name, -> { order('LOWER(name)') }
  scope :for_user, ->(user_id) { joins(:relationships).where(relationships: { user_id: user_id, role_id: Role.hashed['maintainer'] }) }
  scope :related_to_user, ->(user_id) { joins(:relationships).where(relationships: { user_id: user_id }) }
  scope :for_group, ->(group_id) { joins(:relationships).where(relationships: { group_id: group_id, role_id: Role.hashed['maintainer'] }) }
  scope :related_to_group, ->(group_id) { joins(:relationships).where(relationships: { group_id: group_id }) }

  scope :with_product_name, -> { where(name: '_product') }
  scope :with_kind, ->(kind) { joins(:package_kinds).where(package_kinds: { kind: kind }) }

  scope :dirty_backend_packages, -> { left_outer_joins(:backend_package).where(backend_package: { package_id: nil }) }

  validates :name, presence: true, length: { maximum: 200 }
  validates :releasename, length: { maximum: 200 }
  validates :title, length: { maximum: 250 }
  validates :url, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :report_bug_url, length: { maximum: 8192 }
  validate :report_bug_url_is_external
  validates :project_id, uniqueness: {
    scope: :name,
    message: lambda do |object, _data|
      "`#{object.project.name}` already has a package with the name `#{object.name}`"
    end
  }
  validate :valid_name

  has_one :backend_package, foreign_key: :package_id, dependent: :destroy, inverse_of: :package # rubocop:disable Rails/RedundantForeignKey
  has_many :tokens, dependent: :destroy

  def self.check_cache(project, package, opts)
    @key = { 'get_by_project_and_name' => 1, :package => package, :opts => opts }

    @key[:user] = User.session.cache_key_with_version if User.session

    # the cache is only valid if the user, prj and pkg didn't change
    @key[:project] = if project.is_a?(Project)
                       project.id
                     else
                       project
                     end
    pid, old_pkg_time, old_prj_time = Rails.cache.read(@key)
    if pid
      pkg = Package.where(id: pid).includes(:project).first
      return pkg if pkg && pkg.updated_at == old_pkg_time && pkg.project.updated_at == old_prj_time

      Rails.cache.delete(@key) # outdated anyway
    end
    nil
  end

  # Our default finder method that handles all our custom Package features (source access, multibuild, links etc.)
  # Use this method, instead of the default `ActiveRecord::FinderMethods`, if you want to instantiate a Package.
  #
  #   > Package.get_by_project_and_name('home:hennevogel:myfirstproject', 'ctris').name
  #   => "ctris"
  #
  # This method will check if User.possibly_nobody can access the sources of the package using our Role system
  # https://github.com/openSUSE/open-build-service/wiki/Roles
  #
  # You can turn off this check by setting in the opts hash:
  #   use_source: false
  #
  # It will try to find the Package by name even if the name contains the multibuild flavor
  # https://github.com/openSUSE/open-build-service/wiki/Links#multibuild-packages
  #
  #   > Package.get_by_project_and_name('home:hennevogel:myfirstproject', 'ctris:hans').name
  #   Package::Errors::UnknownObjectError: Package not found: home:hennevogel:myfirstproject/ctris:hans
  #
  # You can make it "follow" multibuild flavors (remove everything after the the first occurance of `:`)
  # in the Package name by setting in the opts hash:
  #   follow_multibuild: true
  #
  #   > Package.get_by_project_and_name('home:hennevogel:myfirstproject', 'ctris:hans', follow_multibuild: true).name
  #   => "ctris"
  #
  # It will "follow" project links and find the Package from the Project the link points to.
  # https://github.com/openSUSE/open-build-service/wiki/Links#project-links
  #
  # You can turn off following project links and only try to find the Package in the Project
  # you passed in as first argument by setting in the opts hash:
  #   follow_project_links: false
  #
  # It will ignore "maintenance update" Projects and not "follow" this type of project link to find the Package.
  # https://github.com/openSUSE/open-build-service/wiki/Links#update-instance-project-links
  #
  # You can follow this type of project link and try to find the Package from the "maintenance update"
  # Project by setting in the opts hash:
  #   check_update_project: true
  #
  # It will ignore Project links to remote and not "follow" this type of link to find the Package.
  # https://github.com/openSUSE/open-build-service/wiki/Links#links-to-remote
  #
  # You can follow this type of project link and try to find the Package from the remote Project
  # by setting in the opts hash:
  #   follow_project_remote_links: true
  #
  # It will ignore "scmsync" Projects and not "follow" this type of project link to find the Package.
  # https://github.com/openSUSE/open-build-service/wiki/Links#project-scm-bridge-links
  #
  # You can follow this type of project link and try to find the Package from the "SCM" Project
  # by setting in the opts hash:
  #   follow_project_scmsync_links: true

  def self.get_by_project_and_name(project_name, package_name, opts = {})
    get_by_project_and_name_defaults = { use_source: true,
                                         follow_project_links: true,
                                         follow_project_scmsync_links: false,
                                         follow_project_remote_links: false,
                                         follow_multibuild: false,
                                         check_update_project: false }
    opts = get_by_project_and_name_defaults.merge(opts)

    package_name = striping_multibuild_suffix(package_name) if opts[:follow_multibuild]

    project = Project.get_by_name(project_name)
    return if project.is_a?(String) # no support to instantiate remote packages...

    package = check_cache(project_name, package_name, opts)
    return package if package

    if package.nil? && opts[:follow_project_links]
      package = project.find_package(package_name, opts[:check_update_project])
    elsif package.nil?
      package = project.update_instance_or_self.packages.find_by_name(package_name) if opts[:check_update_project]
      package = project.packages.find_by_name(package_name) if package.nil?
    end

    if package.nil? && project.scmsync.present?
      return nil unless opts[:follow_project_scmsync_links]

      begin
        package_xmlhash = Xmlhash.parse(Backend::Api::Sources::Package.meta(project.name, package_name))
      rescue Backend::NotFoundError
        raise UnknownObjectError, "Package not found: #{project.name}/#{package_name}"
      else
        package = project.packages.new(name: package_name)
        package.assign_attributes_from_from_xml(package_xmlhash)
        package.readonly!
      end
    end

    if package.nil? && project.links_to_remote? && opts[:follow_project_links]
      return nil unless opts[:follow_project_remote_links]

      begin
        package_xmlhash = Xmlhash.parse(Backend::Api::Sources::Package.meta(project.name, package_name))
      rescue Backend::NotFoundError
        raise UnknownObjectError, "Package not found: #{project.name}/#{package_name}"
      else
        package = project.packages.new(name: package_name)
        package.assign_attributes_from_from_xml(package_xmlhash)
        package.readonly!
      end
    end

    raise UnknownObjectError, "Package not found: #{project.name}/#{package_name}" unless package
    raise ReadAccessError, "#{project.name}/#{package.name}" unless package.instance_of?(Package) && package.project.check_access?

    package.check_source_access! if opts[:use_source]

    Rails.cache.write(@key, [package.id, package.updated_at, project.updated_at]) unless package.readonly? # don't cache remote packages...
    package
  end

  # to check existence of a project (local or remote)
  def self.exists_by_project_and_name(project, package, opts = {})
    exists_by_project_and_name_defaults = { follow_project_links: true, allow_remote_packages: false, follow_multibuild: false }
    opts = exists_by_project_and_name_defaults.merge(opts)
    package = striping_multibuild_suffix(package) if opts[:follow_multibuild]
    begin
      prj = Project.get_by_name(project)
    rescue Project::UnknownObjectError
      return false
    end
    return opts[:allow_remote_packages] && exists_on_backend?(package, project) unless prj.is_a?(Project)

    prj.exists_package?(package, opts)
  end

  def self.exists_on_backend?(package, project)
    !Backend::Connection.get(Package.source_path(project, package)).nil?
  rescue Backend::Error
    false
  end

  def self.find_by_project_and_name(project, package)
    PackagesFinder.new.by_package_and_project(package, project).first
  end

  def meta
    PackageMetaFile.new(project_name: project.name, package_name: name)
  end

  def add_maintainer(user)
    add_user(user, 'maintainer')
    save
  end

  def check_source_access?
    return false if (disabled_for?('sourceaccess', nil, nil) || project.disabled_for?('sourceaccess', nil, nil)) && !User.possibly_nobody.can_source_access?(self)

    true
  end

  def check_source_access!
    return if check_source_access?
    # TODO: Use pundit for authorization instead
    raise Authenticator::AnonymousUser, 'Anonymous user is not allowed here - please login' unless User.session

    raise ReadSourceAccessError, "#{project.name}/#{name}"
  end

  def locked?
    return true if flags.find_by_flag_and_status('lock', 'enable')

    project.locked?
  end

  def kiwi_image?
    kiwi_image_file.present?
  end

  def kiwi_image_file
    extract_kiwi_element('name')
  end

  def kiwi_file_md5
    extract_kiwi_element('md5')
  end

  def changes_files
    dir_hash.elements('entry').filter_map do |e|
      e['name'] if /.changes$/.match?(e['name'])
    end
  end

  def commit_message_from_changes_file(target_project, target_package)
    result = ''
    changes_files.each do |changes_file|
      source_changes = PackageFile.new(package_name: name, project_name: project.name, name: changes_file).content
      target_changes = PackageFile.new(package_name: target_package, project_name: target_project, name: changes_file).content
      result << source_changes.try(:chomp, target_changes)
    end
    # Remove header and empty lines
    result.gsub!('-------------------------------------------------------------------', '')
    result.gsub!(/(Mon|Tue|Wed|Thu|Fri|Sat|Sun) ([A-Z][a-z]{2}) ( ?[0-9]|[0-3][0-9]) .*/, '')
    result.gsub!(/^$\n/, '')
    result
  end

  def kiwi_image_outdated?
    return true if kiwi_file_md5.nil? || !kiwi_image

    kiwi_image.md5_last_revision != kiwi_file_md5
  end

  def master_product_object
    # test _product permissions if any other _product: subcontainer is used and _product exists
    return self unless belongs_to_product?

    project.packages.with_product_name.first
  end

  def belongs_to_product?
    /\A_product:\w[-+\w.]*\z/.match?(name) && project.packages.with_product_name.exists?
  end

  # FIXME: Rely on pundit policies instead of this
  def can_be_modified_by?(user, ignore_lock = nil)
    user.can_modify?(master_product_object, ignore_lock)
  end

  def check_write_access!(ignore_lock = nil)
    return if Rails.env.test? && !User.session # for unit tests
    return if can_be_modified_by?(User.possibly_nobody, ignore_lock)

    raise WritePermissionError, "No permission to modify package '#{name}' for user '#{User.possibly_nobody.login}'"
  end

  def check_weak_dependencies?
    develpackages.each do |package|
      errors.add(:base, "used as devel package by #{package.project.name}/#{package.name}")
    end
    return false if errors.any?

    true
  end

  def check_weak_dependencies!(ignore_local: false)
    # check if other packages have me as devel package
    packs = develpackages
    packs = packs.where.not(project: project) if ignore_local
    packs = packs.to_a
    return if packs.empty?

    msg = packs.map { |p| "#{p.project.name}/#{p.name}" }.join(', ')
    de = DeleteError.new("Package is used by following packages as devel package: #{msg}")
    de.packages = packs
    raise de
  end

  def find_project_local_linking_packages
    find_linking_packages(1)
  end

  def find_linking_packages(project_local = nil)
    path = "/search/package/id?match=(linkinfo/@package=\"#{CGI.escape(name)}\"+and+linkinfo/@project=\"#{CGI.escape(project.name)}\""
    path += "+and+@project=\"#{CGI.escape(project.name)}\"" if project_local
    path += ')'
    answer = Backend::Connection.post path
    data = REXML::Document.new(answer.body)
    result = []
    data.elements.each('collection/package') do |e|
      p = Package.find_by_project_and_name(e.attributes['project'], e.attributes['name'])
      if p.nil?
        logger.error 'read permission or data inconsistency, backend delivered package as linked package ' \
                     "where no database object exists: #{e.attributes['project']} / #{e.attributes['name']}"
      else
        result << p
      end
    end
    result
  end

  def update_project_for_product
    return unless name == '_product'

    project.update_product_autopackages
  end

  def private_set_package_kind(dir)
    kinds = Package.detect_package_kinds(dir)

    package_kinds.each do |pk|
      if kinds.include?(pk.kind)
        kinds.delete(pk.kind)
      else
        pk.delete
      end
    end
    kinds.each do |k|
      package_kinds.create(kind: k)
    end
  end

  def unlock_by_request(request)
    f = flags.find_by_flag_and_status('lock', 'enable')
    return unless f

    flags.delete(f)
    store(comment: 'Request got revoked', request: request, lowprio: 1)
  end

  def sources_changed(opts = {})
    dir_xml = opts[:dir_xml]

    # to call update_activity before filter
    # NOTE: We need `Time.now`, otherwise the old tests suite doesn't work,
    # remove it when removing the tests
    update(updated_at: Time.now)

    # mark the backend infos "dirty"
    BackendPackage.where(package_id: id).delete_all
    dir_xml = if dir_xml.is_a?(Net::HTTPSuccess)
                dir_xml.body
              else
                source_file(nil)
              end
    private_set_package_kind(Xmlhash.parse(dir_xml))
    update_project_for_product
    if opts[:wait_for_update]
      update_if_dirty
    else
      # NOTE: Its important that this job run in queue 'default' in order to avoid concurrency
      PackageUpdateIfDirtyJob.perform_later(id)
    end
  end

  def self.source_path(project, package, file = nil, opts = {})
    path = "/source/#{project}/#{package}"
    path = Addressable::URI.escape(path)
    path += "/#{ERB::Util.url_encode(file)}" if file.present?
    path += "?#{opts.to_query}" if opts.present?
    path
  end

  def source_path(file = nil, opts = {})
    Package.source_path(project.name, name, file, opts)
  end

  def source_file(file, opts = {})
    Backend::Connection.get(source_path(file, opts)).body
  end

  def dir_hash(opts = {})
    Directory.hashed(opts.update(project: project.name, package: name))
  end

  def patchinfo?
    of_kind?(:patchinfo)
  end

  def link?
    of_kind?(:link)
  end

  def channel?
    of_kind?(:channel)
  end

  def product?
    of_kind?(:product)
  end

  def of_kind?(kind)
    package_kinds.exists?(kind: kind)
  end

  def ignored_requests
    YAML.safe_load(source_file('ignored_requests')) if file_exists?('ignored_requests')
  end

  def update_issue_list
    current_issues = {}
    if patchinfo?
      xml = Patchinfo.new.read_patchinfo_xmlhash(self)
      xml.elements('issue') do |i|
        current_issues['kept'] ||= []
        current_issues['kept'] << Issue.find_or_create_by_name_and_tracker(i['id'], i['tracker'])
      rescue IssueTracker::NotFoundError => e
        # if the issue is invalid, we ignore it
        Rails.logger.debug e
      end
    else
      # onlyissues backend call gets the issues from .changes files
      current_issues = find_changed_issues
    end

    # fast sync our relations
    PackageIssue.sync_relations(self, current_issues)
  end

  def parse_issues_xml(query, force_state = nil)
    # The issue trackers should have been written to the backend before this point (IssueTrackerWriteToBackendJob)
    begin
      answer = Backend::Connection.post(source_path(nil, query))
    rescue Backend::Error => e
      Rails.logger.debug { "failed to parse issues: #{e.inspect}" }
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
    if link?
      query = { cmd: :linkdiff, onlyissues: 1, linkrev: :base, view: :xml }
      new_issues = parse_issues_xml(query)
      (issue_change.keys + new_issues.keys).uniq.each do |key|
        issue_change[key] ||= {}
        issue_change[key].merge!(new_issues[key]) if new_issues[key]
        issue_change['kept'].delete(new_issues[key]) if issue_change['kept'] && key != 'kept'
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
        t = IssueTracker.find_by_name(tracker)
        next unless t

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

  # rubocop:disable Style/GuardClause
  def update_channel_list
    if channel?
      xml = Backend::Connection.get(source_path('_channel'))
      begin
        channels.first_or_create.update_from_xml(xml.body.to_s)
      rescue ActiveRecord::RecordInvalid => e
        if Rails.env.test?
          raise e
        else
          Airbrake.notify(e, failed_job: "Couldn't store channel")
        end
      end
    else
      channels.destroy_all
    end
  end
  # rubocop:enable Style/GuardClause

  def update_product_list
    # short cut to ensure that no products are left over
    unless product?
      products.destroy_all
      return
    end

    # hash existing entries
    old = {}
    products.each { |p| old[p.name] = p }

    Product.transaction do
      begin
        xml = Xmlhash.parse(Backend::Connection.get(source_path(nil, view: :products)).body)
      rescue StandardError
        next
      end
      xml.elements('productdefinition') do |pd|
        pd.elements('products') do |ps|
          ps.elements('product') do |p|
            product = Product.find_or_create_by_name_and_package(p['name'], self)
            product = product.first unless product.instance_of?(Product)
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
    raise ArgumentError, 'neh!' if directory.key?('time')

    ret = []
    directory.elements('entry') do |e|
      %w[patchinfo aggregate link channel].each do |kind|
        ret << kind if e['name'] == "_#{kind}"
      end
      ret << 'product' if /.product$/.match?(e['name'])
      # further types my be spec, dsc, kiwi in future
    end
    ret.uniq
  end

  # delivers only a defined devel package
  def find_devel_package
    pkg = resolve_devel_package
    return if pkg == self

    pkg
  end

  # delivers always a package
  def resolve_devel_package
    pkg = self
    prj_name = pkg.project.name
    processed = {}

    raise CycleError, 'Package defines itself as devel package' if pkg == pkg.develpackage

    while pkg.develpackage || pkg.project.develproject
      # logger.debug "resolve_devel_package #{pkg.inspect}"

      # cycle detection
      str = "#{prj_name}/#{pkg.name}"
      if processed[str]
        processed.keys.each do |key|
          str = "#{str} -- #{key}"
        end
        raise CycleError, "There is a cycle in devel definition at #{str}"
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
        pkg = prj.packages.find_by(name: pkg.name)
        return if pkg.nil?
      end
      pkg = self if pkg.id == id
    end
    pkg
  end

  def update_from_xml(xmlhash, ignore_lock = nil)
    check_write_access!(ignore_lock)

    Package.transaction do
      assign_attributes_from_from_xml(xmlhash)

      assign_devel_package_from_xml(xmlhash)

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

  def assign_attributes_from_from_xml(xmlhash)
    self.title = xmlhash.value('title')
    self.description = xmlhash.value('description')
    self.url = xmlhash.value('url')
    self.bcntsynctag = xmlhash.value('bcntsynctag')
    self.releasename = xmlhash.value('releasename')
    self.scmsync = xmlhash.value('scmsync')
  end

  def assign_devel_package_from_xml(xmlhash)
    #--- devel project/package ---#
    devel = xmlhash['devel']
    return unless devel

    devel_project_name = devel['project'] || xmlhash['project']
    devel_project = Project.find_by_name(devel_project_name)
    raise SaveError, "project '#{devel_project_name}' does not exist" unless devel_project

    devel_package_name = devel['package'] || xmlhash['name']
    devel_package = devel_project.packages.find_by_name(devel_package_name)
    raise SaveError, "package '#{devel_package_name}' does not exist in project '#{devel_project_name}'" unless devel_package

    self.develpackage = devel_package
  end

  def store(opts = {})
    # no write access check here, since this operation may will disable this permission ...
    self.commit_opts = opts if opts
    save!
  end

  def reset_cache
    Rails.cache.delete("xml_package_#{id}") if id
  end

  def comment=(comment)
    @commit_opts[:comment] = comment
  end

  def write_to_backend
    reset_cache
    raise InvalidParameterError, 'Project meta file can not be written via package model' if name == '_project'

    #--- write through to backend ---#
    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      raise ArgumentError, 'no commit_user set' unless commit_user

      query = { user: commit_user.login }
      query[:comment] = @commit_opts[:comment] if @commit_opts[:comment].present?
      # the request number is the requestid parameter in the backend api
      query[:requestid] = @commit_opts[:request].number if @commit_opts[:request]
      Backend::Connection.put(source_path('_meta', query), to_axml)
      logger.tagged('backend_sync') { logger.debug "Saved Package #{project.name}/#{name}" }
    elsif @commit_opts[:no_backend_write]
      logger.tagged('backend_sync') { logger.warn "Not saving Package #{project.name}/#{name}, backend_write is off " }
    else
      logger.tagged('backend_sync') { logger.warn "Not saving Package #{project.name}/#{name}, global_write_through is off" }
    end
  end

  def delete_on_backend
    # lock this package object to avoid that dependend objects get created in parallel
    # for example a backend_package
    reload(lock: true)

    # not really packages...
    # everything below _product:
    return if belongs_to_product?
    return if name == '_project'

    raise ArgumentError, 'no commit_user set' unless commit_user

    if CONFIG['global_write_through'] && !@commit_opts[:no_backend_write]
      path = source_path

      h = { user: commit_user.login }
      h[:comment] = commit_opts[:comment] if commit_opts[:comment]
      h[:requestid] = commit_opts[:request].number if commit_opts[:request]
      path << Backend::Connection.build_query_from_hash(h, %i[user comment requestid])
      begin
        Backend::Connection.delete path
      rescue Backend::NotFoundError
        # ignore this error, backend was out of sync
        logger.tagged('backend_sync') { logger.warn("Package #{project.name}/#{name} was already missing on backend on removal") }
      end
      logger.tagged('backend_sync') { logger.warn("Deleted Package #{project.name}/#{name}") }
    elsif @commit_opts[:no_backend_write]
      logger.tagged('backend_sync') { logger.warn "Not deleting Package #{project.name}/#{name}, backend_write is off " } unless @commit_opts[:project_destroy_transaction]
    else
      logger.tagged('backend_sync') { logger.warn "Not deleting Package #{project.name}/#{name}, global_write_through is off" }
    end
  end

  def to_axml_id
    "<package project='#{::Builder::XChar.encode(project.name)}' name='#{::Builder::XChar.encode(name)}'/>\n"
  end

  def to_axml(_opts = {})
    Rails.cache.fetch("xml_package_#{id}") do
      # CanRenderModel
      render_xml
    end
  end

  def self.activity_algorithm
    # this is the algorithm (sql) we use for calculating activity of packages
    # NOTE: We use Time.now.to_i instead of UNIX_TIMESTAMP() so we can test with frozen ruby time in the old tests suite,
    # change it when removing the tests
    '( packages.activity_index * ' \
      "POWER( 2.3276, (UNIX_TIMESTAMP(packages.updated_at) - #{Time.now.to_i})/10000000 ) " \
      ') as activity_value'
  end

  before_validation(on: :create) do
    # it lives but is new
    self.activity_index = 20
  end

  def activity
    activity_index * (2.3276**((updated_at_was.to_f - Time.now.to_f) / 10_000_000))
  end

  def open_requests_with_package_as_target
    rel = BsRequest.where(state: %i[new review declined]).joins(:bs_request_actions)
    rel = rel.where('(bs_request_actions.target_project = ? and bs_request_actions.target_package = ?)', project.name, name)
    BsRequest.where(id: rel.select('bs_requests.id'))
  end

  def open_requests_with_package_as_source
    rel = BsRequest.where(state: %i[new review declined]).joins(:bs_request_actions)
    rel = rel.where('(bs_request_actions.source_project = ? and bs_request_actions.source_package = ?)', project.name, name)
    BsRequest.where(id: rel.select('bs_requests.id'))
  end

  def open_requests_with_by_package_review
    rel = BsRequest.where(state: %i[new review])
    rel = rel.joins(:reviews).where("reviews.state = 'new' and reviews.by_project = ? and reviews.by_package = ? ", project.name, name)
    BsRequest.where(id: rel.select('bs_requests.id'))
  end

  def self.extended_name(project, package)
    # the package name which will be used on a branch with extended or maintenance option
    directory_hash = Directory.hashed(project: project, package: package)
    linkinfo = directory_hash['linkinfo'] || {}

    "#{linkinfo['package'] || package}.#{linkinfo['project'] || project}".tr(':', '_')
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
    Service.new(package: self)
  end

  def buildresult(prj = project, show_all: false, lastbuild: false)
    LocalBuildResult::ForPackage.new(package: self, project: prj, show_all: show_all, lastbuild: lastbuild)
  end

  # FIXME: That you can overwrite package_name is rather confusing, but needed because of multibuild :-/
  def jobhistory(repository_name:, arch_name:, package_name: name, project_name: project.name, filter: { limit: 100, start_epoch: nil, end_epoch: nil, code: [] })
    Backend::Api::BuildResults::JobHistory.for_package(project_name: project_name,
                                                       package_name: package_name,
                                                       repository_name: repository_name,
                                                       arch_name: arch_name,
                                                       filter: filter)
  end

  def service_error(revision = nil)
    revision ||= serviceinfo['xsrcmd5']
    return nil unless revision

    PackageServiceErrorFile.new(project_name: project.name, package_name: name).content(rev: revision)
  end

  def local_link?
    linkinfo = dir_hash['linkinfo']

    linkinfo && (linkinfo['project'] == project.name)
  end

  def modify_channel(mode = :add_disabled)
    raise InvalidParameterError unless %i[add_disabled enable_all].include?(mode)

    channel = channels.first
    return unless channel

    channel.add_channel_repos_to_project(self, mode)
  end

  def add_channels(mode = :add_disabled)
    raise InvalidParameterError unless %i[add_disabled skip_disabled enable_all].include?(mode)
    return if channel?

    opkg = origin_container(local: false)
    # remote or broken link?
    return if opkg.nil?

    # Update projects are usually used in _channels
    project_name = opkg.project.update_instance_or_self.name

    # not my link target, so it does not qualify for my code streastream
    return unless linkinfo && project_name == linkinfo['project']

    # main package
    name = opkg.name.dup
    # strip incident suffix in update release projects
    # but beware of packages where the name has already a dot
    name.gsub!(/\.[^.]*$/, '') if opkg.project.maintenance_release? && !opkg.link?
    ChannelBinary.find_by_project_and_package(project_name, name).each do |cb|
      _add_channel(mode, cb, "Listed in #{project_name} #{name}")
    end
    # Invalidate cache after adding first batch of channels. This is needed because
    # we add channels for linked packages before calling store, which would update the
    # timestamp used for caching.
    # rubocop:disable Rails/SkipsModelValidations
    project.touch
    # rubocop:enable Rails/SkipsModelValidations

    # and all possible existing local links
    opkg = opkg.project.packages.find_by_name(opkg.linkinfo['package']) if opkg.project.maintenance_release? && opkg.link?

    opkg.find_project_local_linking_packages.each do |p|
      name = p.name
      # strip incident suffix in update release projects
      name.gsub!(/\.[^.]*$/, '') if opkg.project.maintenance_release?
      ChannelBinary.find_by_project_and_package(project_name, name).each do |cb|
        _add_channel(mode, cb, "Listed in #{project_name} #{name}")
      end
    end
    project.store
  end

  def update_instance(namespace = 'OBS', name = 'UpdateProject')
    # check if a newer instance exists in a defined update project
    project.update_instance_or_self(namespace, name).find_package(self.name)
  end

  def developed_packages
    packages = []
    candidates = Package.where(develpackage_id: self).load
    candidates.each do |candidate|
      packages << candidate unless candidate.linkinfo
    end
    packages
  end

  def self.valid_name?(name, allow_multibuild: false)
    return false unless name.is_a?(String)
    # this length check is duplicated but useful for other uses for this function
    return false if name.length > 200
    return false if name == '0'
    return true if %w[_product _pattern _project _patchinfo].include?(name)

    # _patchinfo: is obsolete, just for backward compatibility
    allowed_characters = /[-+\w.#{allow_multibuild ? ':' : ''}]/
    reg_exp = /\A([a-zA-Z0-9]|(_product:|_patchinfo:)\w)#{allowed_characters}*\z/
    reg_exp.match?(name)
  end

  def valid_name
    errors.add(:name, 'is illegal') unless Package.valid_name?(name)
  end

  def branch_from(origin_project, origin_package, opts)
    myparam = { cmd: 'branch',
                noservice: '1',
                oproject: origin_project,
                opackage: origin_package,
                user: User.session!.login }
    # merge additional key/values, avoid overwrite. _ is needed for rubocop
    myparam.merge!(opts) { |_key, v1, _v2| v1 }
    path = source_path
    path += Backend::Connection.build_query_from_hash(myparam,
                                                      %i[cmd oproject opackage user comment
                                                         orev missingok noservice olinkrev extendvrev])
    # branch sources in backend
    Backend::Connection.post path
  end

  # just make sure the backend_package is there
  def update_if_dirty
    backend_package
  rescue Mysql2::Error
    # the delayed job might have jumped in and created the entry just before us
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
    bp.maxmtime = if dir['revtime'].blank? # no commit, no revtime
                    nil
                  else
                    Time.at(Integer(dir['revtime']))
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

      Rails.logger.debug { "Syncing link #{project.name}/#{name} -> #{li['project']}/#{li['package']}" }
      # we have to be careful - the link target can be nowhere
      bp.links_to = Package.find_by_project_and_name(li['project'], li['package'])
    else
      bp.error = nil
      bp.links_to = nil
    end
  end

  def remove_linked_packages
    BackendPackage.where(links_to_id: id).delete_all
  end

  def remove_devel_packages
    Package.where(develpackage: self).find_each do |devel_package|
      devel_package.develpackage = nil
      devel_package.store
      devel_package.reset_cache
    end
  end

  def decline_requests_with_self_as_target(message = nil)
    message ||= "The package '#{project.name}/#{name}' has been removed"

    open_requests_with_package_as_target.each do |request|
      # Don't alter the request that is the trigger of this close_requests run
      next if request == @commit_opts[:request]

      logger.debug "#{self.class} #{name} doing decline_requests_with_self_as_target on request #{request.id} with #{@commit_opts.inspect}"

      begin
        request.change_state(newstate: 'declined', comment: message)
      rescue PostRequestNoPermission
        logger.info "#{User.session!.login} tried to decline request #{id} but had no permissions"
      end
    end
  end

  def revoke_requests_with_self_as_source(message = nil)
    message ||= "The package '#{project.name}/#{name}' has been removed"

    open_requests_with_package_as_source.each do |request|
      # Don't alter the request that is the trigger of this close_requests run
      next if request == @commit_opts[:request]

      logger.debug "#{self.class} #{name} doing revoke_requests_with_self_as_source on request #{request.id} with #{@commit_opts.inspect}"

      begin
        request.change_state(newstate: 'revoked', comment: message)
      rescue PostRequestNoPermission
        logger.info "#{User.session!.login} tried to revoke request #{id} but had no permissions"
      end
    end
  end

  def obsolete_reviews_for_self
    open_requests_with_by_package_review.each do |request|
      # Don't alter the request that is the trigger of this close_requests run
      next if request.id == @commit_opts[:request]

      request.obsolete_reviews(by_project: project.name, by_package: name)
    end
  end

  def patchinfo
    Patchinfo.new(data: source_file('_patchinfo'))
  rescue Backend::NotFoundError
    nil
  end

  def delete_file(name, opt = {})
    raise ScmsyncReadOnly if scmsync.present?

    delete_opt = {}
    delete_opt[:keeplink] = 1 if opt[:expand]
    delete_opt[:user] = User.session!.login
    delete_opt[:comment] = opt[:comment] if opt[:comment]

    raise DeleteFileNoPermission, 'Insufficient permissions to delete file' unless User.session!.can_modify?(self)

    Backend::Connection.delete source_path(name, delete_opt)
    sources_changed
  end

  def enable_for_repository(repo_name)
    update_needed = nil
    if project.flags.find_by_flag_and_status('build', 'disable')
      # enable package builds if project default is disabled
      flags.find_or_create_by(flag: 'build', status: 'enable', repo: repo_name)
      update_needed = true
    end
    if project.flags.find_by_flag_and_status('debuginfo', 'disable')
      # take over debuginfo config from origin project
      flags.find_or_create_by(flag: 'debuginfo', status: 'enable', repo: repo_name)
      update_needed = true
    end
    store if update_needed
  end

  def serviceinfo
    begin
      dir = Directory.hashed(project: project.name, package: name)
      return dir.fetch('serviceinfo', {}) if dir
    rescue Backend::NotFoundError
      # Ignore this exception on purpose
    end
    {}
  end

  # the revision might match a backend revision that is not in _history
  # e.g. on expanded links - in this case we return nil
  def commit(rev = nil)
    if rev && rev.to_i.negative?
      # going backward from not yet known current revision, find out ...
      r = self.rev.to_i + rev.to_i + 1
      rev = r.to_s
      return if rev.to_i < 1
    end

    Xmlhash.parse(Backend::Api::Sources::Package.revisions(project.name, name, { rev: rev || self.rev, deleted: 0, meta: 0 })).elements('revision').first
  end

  def self.verify_file!(pkg, name, content)
    raise IllegalFileName if name == '_attribute'

    PackageService::FileVerifier.new(package: pkg, file_name: name, content: content).call
  end

  def save_file(opt = {})
    raise ScmsyncReadOnly if scmsync.present?

    content = '' # touch an empty file first
    content = opt[:file] if opt[:file]

    logger.debug "storing file: filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    Package.verify_file!(self, opt[:filename], content)
    raise PutFileNoPermission, "Insufficient permissions to store file in package #{name}, project #{project.name}" unless User.session!.can_modify?(self)

    params = opt.slice(:comment, :rev) || {}
    params[:user] = User.session!.login
    Backend::Api::Sources::Package.write_file(project.name, name, opt[:filename], content, params)

    # KIWI file
    if /\.kiwi\.txz$/.match?(opt[:filename])
      logger.debug 'Found a kiwi archive, creating kiwi_import source service'
      services = self.services
      services.add_kiwi_import
    end

    # update package timestamp and reindex sources
    return if opt[:rev] == 'repository' || %w[_project _pattern].include?(name)

    sources_changed(wait_for_update: %w[_aggregate _constraints _link _service _patchinfo _channel].include?(opt[:filename]))
  end

  def to_param
    name
  end

  def to_s
    name
  end

  def fixtures_name
    "#{project.name}_#{name}".tr(':', '_')
  end

  def release_target_name(target_repo = nil, time = Time.now.utc)
    if releasename.nil? && project.maintenance_incident? && linkinfo && linkinfo['package']
      # old incidents special case
      return linkinfo['package']
    end

    basename = releasename || name

    # The maintenance ID is always the sub project name of the maintenance project
    return "#{basename}.#{project.basename}" if project.maintenance_incident?

    # Fallback for releasing into a release project outside of maintenance incident
    # avoid overwriting existing binaries in this case
    return "#{basename}.#{time.strftime('%Y%m%d%H%M%S')}" if target_repo && target_repo.project.maintenance_release?

    basename
  end

  def file_exists?(filename, opts = {})
    dir_hash(opts).key?('entry') && [dir_hash(opts)['entry']].flatten.compact.any? { |item| item['name'] == filename }
  end

  def icon?
    file_exists?('_icon')
  end

  def self.what_depends_on(project, package, repository, architecture)
    path = "/build/#{project}/#{repository}/#{architecture}/_builddepinfo?package=#{package}&view=revpkgnames"
    [Xmlhash.parse(Backend::Connection.get(path).body).try(:[], 'package').try(:[], 'pkgdep')].flatten.compact
  rescue Backend::NotFoundError
    []
  end

  def last_build_reason(repo, arch, package_name = nil)
    repo = repo.name if repo.is_a?(Repository)

    begin
      build_reason = Backend::Api::BuildResults::Status.build_reason(project.name, package_name || name, repo, arch)
    rescue Backend::NotFoundError
      return PackageBuildReason.new
    end

    data = Xmlhash.parse(build_reason)
    # ensure that if 'packagechange' exists, it is an Array and not a Hash
    # Bugreport: https://github.com/openSUSE/open-build-service/issues/3230
    data['packagechange'] = [data['packagechange']] if data && data['packagechange'].is_a?(Hash)

    PackageBuildReason.new(data)
  end

  def event_parameters
    { project: project.name, package: name }
  end

  def bugowner_emails
    (relationships.bugowners_with_email.pluck(:email) + project.bugowner_emails).uniq
  end

  # Returns an ActiveRecord::Relation with all BsRequest that the package is somehow involved in
  def bs_requests
    BsRequest.left_outer_joins(:bs_request_actions, :reviews)
             .where(reviews: { package_id: id })
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { source_package_id: id }))
             .or(BsRequest.left_outer_joins(:bs_request_actions, :reviews).where(bs_request_actions: { target_package_id: id }))
             .distinct
  end

  private

  def extract_kiwi_element(element)
    kiwi_file = dir_hash.elements('entry').find { |e| e['name'] =~ /.kiwi$/ }
    kiwi_file[element] unless kiwi_file.nil?
  end

  def _add_channel(mode, channel_binary, message)
    # set to disabled
    return if channel_binary.channel_binary_list.channel.disabled

    # add source container
    return if mode == :skip_disabled && !channel_binary.channel_binary_list.channel.active?

    cpkg = channel_binary.create_channel_package_into(project, message)
    return unless cpkg

    # be sure that the object exists or a background job get launched
    cpkg.backend_package
    # add and enable repos
    return if mode == :add_disabled && !channel_binary.channel_binary_list.channel.active?

    cpkg.channels.first.add_channel_repos_to_project(cpkg, mode)
  end

  # is called before_update
  def update_activity
    # the value we add to the activity, when the object gets updated
    addon = (Time.now.to_f - updated_at_was.to_f) * 10 / 86_400
    addon = 10 if addon > 10
    new_activity = activity + addon
    [new_activity, 100].min

    self.activity_index = new_activity
  end

  def populate_to_sphinx
    PopulateToSphinxJob.perform_later(id: id, model_name: :package)
  end

  def delete_from_sphinx
    DeleteFromSphinxJob.perform_later(id, self.class)
  end

  def backfill_bs_request_actions
    # rubocop:disable Rails/SkipsModelValidations
    # Source package
    BsRequestAction.where(source_project: project.name, source_package: name).update_all(source_package_id: id)

    # Target package
    BsRequestAction.where(target_project: project.name, target_package: name).update_all(target_package_id: id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def convert_to_symsync
    return unless saved_change_to_attribute?('scmsync', from: nil)

    package_kinds.delete_all
    BackendPackage.where(package_id: id).delete_all
    decline_requests_with_self_as_target("The package '#{project.name} / #{name}' is now maintained at #{scmsync}")
  end

  def report_bug_url_is_external
    return true unless report_bug_url

    parsed_instance_url = URI.parse(Configuration.obs_url)
    parsed_report_bug_url = URI.parse(report_bug_url)

    # If uri's do not have the schema set up, like 'localhost:3000' they are
    # detected as Generic protocol and the detection of the fragments is a
    # bit... weird.
    if parsed_report_bug_url.is_a?(URI::Generic)
      errors.add(:report_bug_url, 'Local urls are not allowed') if parsed_report_bug_url.path&.starts_with?('/')
      # urls like localhost:3000 have no path and no host, and the schema is 'localhost'
      errors.add(:report_bug_url, 'Local urls are not allowed') if parsed_report_bug_url.scheme == parsed_instance_url.host
    elsif parsed_report_bug_url == parsed_instance_url
      errors.add(:report_bug_url, 'Local urls are not allowed')
    end
  end
end
# rubocop: enable Metrics/ClassLength

# == Schema Information
#
# Table name: packages
#
#  id              :integer          not null, primary key
#  activity_index  :float(24)        default(100.0)
#  bcntsynctag     :string(255)
#  delta           :boolean          default(TRUE), not null
#  description     :text(65535)
#  name            :string(200)      not null, indexed => [project_id]
#  releasename     :string(255)
#  report_bug_url  :string(8192)
#  scmsync         :string(255)
#  title           :string(255)
#  url             :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  develpackage_id :integer          indexed
#  kiwi_image_id   :integer          indexed
#  project_id      :integer          not null, indexed => [name]
#
# Indexes
#
#  devel_package_id_index           (develpackage_id)
#  index_packages_on_kiwi_image_id  (kiwi_image_id)
#  packages_all_index               (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...     (kiwi_image_id => kiwi_images.id)
#  packages_ibfk_3  (develpackage_id => packages.id)
#  packages_ibfk_4  (project_id => projects.id)
#
