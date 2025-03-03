# a Patchinfo lives in a Project, but is not a package - it represents a special file
# in a update package

# if you wonder it's not a module, read http://blog.codeclimate.com/blog/2012/11/14/why-ruby-class-methods-resist-refactoring
class Patchinfo
  include ValidationHelper
  include ActiveModel::Model

  class PatchinfoFileExists < APIError; end

  class IncompletePatchinfo < APIError; end

  class ReleasetargetNotFound < APIError
    setup 404
  end

  class TrackerNotFound < APIError
    setup 404
  end

  # FIXME: Layout and colors belong to CSS
  RATING_COLORS = {
    'low' => 'green',
    'moderate' => 'olive',
    'important' => 'red',
    'critical' => 'maroon'
  }.freeze

  RATINGS = RATING_COLORS.keys.freeze

  CATEGORY_COLORS = {
    'recommended' => 'green',
    'security' => 'maroon',
    'optional' => 'olive',
    'feature' => '',
    'ptf' => ''
  }.freeze

  # '' is a valid category
  CATEGORIES = (CATEGORY_COLORS.keys << '').freeze

  attr_reader :document
  attr_writer :data
  attr_accessor :summary, :description, :packager, :category, :rating, :name,
                :binaries, :version, :message, :retracted, :relogin_needed,
                :reboot_needed, :zypp_restart_needed, :block, :block_reason, :issues,
                :issueid, :issuetracker, :issueurl, :issuesum

  validates :summary, length: { minimum: 10 }
  validates :description, length: { minimum: 50 }
  validates :packager, presence: true
  validate :issue_tracker_existence

  def hashed
    Xmlhash.parse(document.to_xml)
  end

  # patchinfo has two roles
  def initialize(attributes = {})
    super

    @data ||= '<patchinfo/>'
    @document = Nokogiri::XML(@data, &:strict)
  end

  def repository_matching?(repo, rt)
    return false if repo.project.name != rt['project']

    return false if rt['repository'] && (repo.name != rt['repository'])

    true
  end

  # check if we can find the releasetarget (xmlhash) in the project
  def check_releasetarget!(rt)
    @project.repositories.each do |r|
      r.release_targets.each do |prt|
        return if repository_matching?(prt.target_repository, rt)
      end
    end
    raise ReleasetargetNotFound, "Release target '#{rt['project']}/#{rt['repository']}' is not defined " \
                                 "in this project '#{@project.name}'. Please ask your OBS administrator to add it."
  end

  def verify_data(project, raw_post)
    @project = project
    data = Xmlhash.parse(raw_post)
    # check the packager field
    User.find_by_login!(data['packager']) if data['packager']
    # valid tracker?
    data.elements('issue').each do |i|
      tracker = IssueTracker.find_by_name(i['tracker'])
      raise TrackerNotFound, "Tracker #{i['tracker']} is not registered in this OBS instance" unless tracker

      issue = Issue.new(name: i['id'], issue_tracker: tracker)
      raise Issue::InvalidName, issue.errors.full_messages.to_sentence unless issue.valid?
    end
    # are releasetargets specified ? validate that this project is actually defining them.
    data.elements('releasetarget') { |r| check_releasetarget!(r) }
  end

  def add_issue_to_patchinfo(issue)
    tracker = issue.issue_tracker
    return if @patchinfo.document.xpath("issue[(@id='#{issue.name}' and @tracker='#{tracker.name}')]").present?

    @patchinfo.document.root.add_child("<issue id='#{issue.name}' tracker='#{tracker.name}'/>")
    @patchinfo.document.at_css('category').content = 'security' if tracker.kind == 'cve'
  end

  def fetch_issue_for_package(package)
    # create diff per package
    return if package.patchinfo?

    package.package_issues.each do |i|
      add_issue_to_patchinfo(i.issue) if i.change == 'added'
    end
  end

  def update_patchinfo(project, patchinfo, opts = {})
    project.check_write_access!
    @patchinfo = patchinfo

    opts[:enfore_issue_update] ||= false

    # collect bugnumbers from diff
    project.packages.each { |p| fetch_issue_for_package(p) }

    # update informations of empty issues
    patchinfo.document.css('issue').each do |i|
      next if i.content.present? || i['name'].blank?

      issue = Issue.find_or_create_by_name_and_tracker(i['name'], i['tracker'])
      next unless issue

      # enforce update from issue server
      issue.fetch_updates if opts[:enfore_issue_update]
      i.text = issue.summary
    end
    patchinfo
  end

  def patchinfo_node(project)
    xml = Nokogiri::XML('<patchinfo/>').root
    if project.maintenance_incident?
      # this is a maintenance incident project, the sub project name is the maintenance ID
      xml.set_attribute('incident', @pkg.project.name.gsub(/.*:/, ''))
    end
    xml.add_child('<category>recommended</category>')
    xml.add_child('<rating>low</rating>')
    xml
  end

  def create_patchinfo_from_request(project, req)
    project.check_write_access!
    @prj = project

    # create patchinfo package
    create_patchinfo_package('patchinfo')

    # create patchinfo XML file
    xml = patchinfo_node(project)

    description = req.description || ''
    xml.add_child("<packager>#{CGI.escapeHTML(req.creator)}</packager>")
    xml.add_child("<summary>#{CGI.escapeHTML(description.split(/\n|\r\n/)[0] || '')}</summary>") # first line only
    xml.add_child("<description>#{CGI.escapeHTML(description)}</description>")

    xml = update_patchinfo(project, xml, enfore_issue_update: true)
    Backend::Api::Sources::Package.write_patchinfo(@pkg.project.name, @pkg.name, User.session!.login, xml.to_xml,
                                                   "generated by request id #{req.number} accept call")
    @pkg.sources_changed
  end

  def create_patchinfo_package(pkg_name)
    Package.transaction do
      @pkg = @prj.packages.new(name: pkg_name, title: 'Patchinfo', description: 'Collected packages for update')
      @pkg.add_flag('build', 'enable', nil, nil)
      @pkg.add_flag('publish', 'enable', nil, nil) unless @prj.flags.find_by_flag_and_status('access', 'disable')
      @pkg.add_flag('useforbuild', 'disable', nil, nil)
      @pkg.store
    end
  end

  def require_package_for_patchinfo(project, pkg_name, force)
    pkg_name ||= 'patchinfo'
    valid_package_name!(pkg_name)

    # create patchinfo package
    unless Package.exists_by_project_and_name(project, pkg_name)
      @prj = Project.get_by_name(project)
      create_patchinfo_package(pkg_name)
      return
    end

    @pkg = Package.get_by_project_and_name(project, pkg_name)
    return if force

    if @pkg.patchinfo?
      raise PatchinfoFileExists, "createpatchinfo command: the patchinfo #{pkg_name} exists already. " \
                                 'Either use force=1 re-create the _patchinfo or use updatepatchinfo for updating.'
    else
      raise PackageAlreadyExists, "createpatchinfo command: the package #{pkg_name} exists already, " \
                                  'but is  no patchinfo. Please create a new package instead.'
    end
  end

  def create_patchinfo(project, pkg_name, opts = {})
    require_package_for_patchinfo(project, pkg_name, opts[:force])

    # create patchinfo XML file
    xml = patchinfo_node(@pkg.project)
    xml.add_child("<packager>#{CGI.escapeHTML(User.session!.login)}</packager>")
    if opts[:comment].present?
      xml.add_child("<summary>#{CGI.escapeHTML(opts[:comment])}</summary>")
    else
      xml.add_child('<summary/>')
    end
    xml.add_child('<description/>')
    xml = update_patchinfo(@pkg.project, xml)
    if CONFIG['global_write_through']
      Backend::Api::Sources::Package.write_patchinfo(@pkg.project.name, @pkg.name, User.session!.login, xml.to_xml,
                                                     'generated by createpatchinfo call')
    end
    @pkg.sources_changed
    { targetproject: @pkg.project.name, targetpackage: @pkg.name }
  end

  def cmd_update_patchinfo(project, package, message = 'updated via updatepatchinfo call')
    pkg = Package.get_by_project_and_name(project, package)

    # get existing file
    xml = pkg.patchinfo
    xml = update_patchinfo(pkg.project, xml)

    Backend::Api::Sources::Package.write_patchinfo(pkg.project.name, pkg.name, User.session!.login, xml.document.to_xml, message)
    pkg.sources_changed
  end

  def read_patchinfo_xmlhash(pkg)
    xml = Xmlhash.parse(pkg.source_file('_patchinfo'))
    # patch old data to stay compatible
    xml.elements('issue') do |i|
      i['id'].gsub!(/^(CVE|cve)-/, '') if i['tracker'] == 'cve'
    end
    xml
  end

  def fetch_release_targets(pkg)
    data = read_patchinfo_xmlhash(pkg)
    # validate _patchinfo for completeness
    raise IncompletePatchinfo, 'The _patchinfo file is not parseble' if data.empty?

    %w[rating category summary].each do |field|
      raise IncompletePatchinfo, "The _patchinfo has no #{field} set" if data[field].blank?
    end
    # a patchinfo may limit the targets
    data.elements('releasetarget')
  end

  def issues_by_tracker
    issues_by_tracker = {}
    issues.each do |issue|
      issues_by_tracker[issue.value('tracker')] ||= []
      issues_by_tracker[issue.value('tracker')] << issue
    end
    issues_by_tracker
  end

  def load_from_xml(patchinfo_xml)
    self.binaries = []
    patchinfo_xml.elements('binary').each do |binaries|
      self.binaries << binaries
    end
    self.packager = patchinfo_xml.value('packager')
    self.version = patchinfo_xml['version']

    self.issues = []
    patchinfo_xml.elements('issue') do |issue_element|
      if issue_element['_content'].blank?
        # old uploaded patchinfos could have broken tracker-names like "bnc "
        # instead of "bnc". Catch these.
        begin
          summary = IssueTracker::IssueSummary.new(issue_element['tracker'], issue_element['id'])
          issue_element['_content'] = summary.issue_summary if summary.belongs_bug_to_tracker?
        rescue Backend::NotFoundError
          issue_element['_content'] = 'PLEASE CHECK THE FORMAT OF THE ISSUE'
        end
      end

      issues << [
        issue_element['id'],
        issue_element['tracker'],
        IssueTracker.find_by_name(issue_element['tracker']).try(:show_url_for, issue_element['id']).to_s,
        issue_element['_content']
      ]
    end
    self.category = patchinfo_xml.value('category')
    self.rating = patchinfo_xml.value('rating')
    self.summary = patchinfo_xml.value('summary')
    self.name = patchinfo_xml.value('name')

    self.description = patchinfo_xml.value('description')
    self.message = patchinfo_xml.value('message')
    self.relogin_needed = !patchinfo_xml.value('relogin_needed').nil?
    self.reboot_needed = !patchinfo_xml.value('reboot_needed').nil?
    self.retracted = !patchinfo_xml.value('retracted').nil?
    self.zypp_restart_needed = !patchinfo_xml.value('zypp_restart_needed').nil?
    if patchinfo_xml.value('stopped')
      self.block = true
      self.block_reason = patchinfo_xml.value('stopped')
    end

    self
  end

  def to_xml(project, package)
    self.issues = []
    issueid.to_a.each_with_index do |new_issue, index|
      issues << [
        new_issue,
        issuetracker[index],
        IssueTracker.find_by_name(issuetracker[index]).try(:show_url_for, new_issue).to_s,
        issuesum[index]
      ]
    end
    node = Builder::XmlMarkup.new(indent: 2)
    attrs = {
      incident: project.name.gsub(/.*:/, '')
    }
    attrs[:version] = version if version.present?
    node.patchinfo(attrs) do
      binaries.to_a.each { |binary| node.binary(binary) }
      node.name(name) if name.present?
      node.packager(packager)
      issues.to_a.each do |issue|
        # people tend to enter entire cve strings instead of just the name
        issue[0].gsub!(/^(CVE|cve)-/, '') if issue[1] == 'cve'
        node.issue(issue[3], tracker: issue[1], id: issue[0])
      end
      node.category(category.try(:strip))
      node.rating(rating.try(:strip))
      node.summary(summary.try(:strip))
      node.description(description.gsub("\r\n", "\n"))
      file = package.patchinfo
      file.hashed.elements('package') do |pkg|
        node.package(pkg['_content'])
      end
      file.hashed.elements('releasetarget') do |release_target|
        attributes = { project: release_target['project'] }
        attributes[:repository] = release_target['repository'] if release_target['repository']
        node.releasetarget(attributes)
      end
      node.message message.gsub("\r\n", "\n") if message.present?
      node.reboot_needed if reboot_needed == '1'
      node.relogin_needed if relogin_needed == '1'
      node.retracted if retracted == '1'
      node.zypp_restart_needed if zypp_restart_needed == '1'
      node.stopped block_reason if block == '1'
    end
  end

  private

  def issue_tracker_existence
    return if issuetracker.blank?

    unknown_issue_trackers = issuetracker.uniq - IssueTracker.where(name: issuetracker).pluck(:name)
    return if unknown_issue_trackers.empty?

    errors.add(:base, "Unknown Issue trackers: #{unknown_issue_trackers.to_sentence}")
  end
end
