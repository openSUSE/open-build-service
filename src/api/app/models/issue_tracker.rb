require 'xmlrpc/client'

class IssueTracker < ApplicationRecord
  has_many :issues, dependent: :destroy

  class NotFoundError < APIException
    setup 'issue_tracker_not_found', 404, 'Issue Tracker not found'
  end
  class InvalidIssueName < APIException; end

  validates :name, :regex, :url, :kind, presence: true
  validates :name, :regex, uniqueness: true
  validates :kind, inclusion: { in: %w(other bugzilla cve fate trac launchpad sourceforge github) }

  if CONFIG['global_write_through']
    after_save :delayed_write_to_backend
    after_save :update_package_meta
  end

  # FIXME: issues_updated should not be hidden, but it should also not break our api
  DEFAULT_RENDER_PARAMS = { except: [:id, :password, :user, :issues_updated], dasherize: true, skip_types: true, skip_instruct: true }.freeze

  def delayed_write_to_backend
    IssueTrackerWriteToBackendJob.perform_later
  end

  def update_package_meta
    # We need to parse again ALL sources ...
    UpdatePackageMetaJob.perform_later
  end

  before_validation(on: :create) do
    self.issues_updated ||= Time.now
  end

  def cve?
    kind == 'cve'
  end

  def valid_issue_name?(name)
    Issue.valid_name?(self, name)
  end

  # Checks if the given issue belongs to this issue tracker
  #  def matches?(issue)
  #    return Regexp.new(regex).match(issue)
  #  end

  # Generates a URL to display a given issue in the upstream issue tracker
  def show_url_for(issue, html = nil)
    return unless issue
    url = show_url.gsub('@@@', issue)
    return "<a href=\"#{url}\">#{CGI.escapeHTML(show_label_for(issue))}</a>" if html
    url
  end

  def show_label_for(issue)
    label.gsub('@@@', issue)
  end

  # expands all matches with defined urls
  def get_html(text)
    text.gsub(Regexp.new(regex)) { show_url_for($1, true) }
  end

  def get_markdown(text)
    text.gsub(Regexp.new(regex)) { "[#{$&}](#{show_url_for($1, false)})" }
  end

  def update_issues_bugzilla
    return unless enable_fetch

    begin
      result = bugzilla_server.search(last_change_time: self.issues_updated)
    rescue Net::ReadTimeout
      if (self.issues_updated + 2.days).past?
        # failures since two days?
        # => enforce a full update in small steps to avoid over load at bugzilla side
        enforced_update_all_issues
        return true
      end
      return false
    end
    ids = result['bugs'].map { |x| x['id'].to_i }

    return unless private_fetch_issues(ids)

    # skip callbacks to avoid scheduling expensive jobs

    # rubocop:disable Rails/SkipsModelValidations
    update_columns(issues_updated: @update_time_stamp)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def update_issues_github
    return unless enable_fetch

    # must be like this "url = https://github.com/repos/#{self.owner}/#{self.name}/issues"
    url = URI.parse("#{self.url}?since=#{self.issues_updated.to_time.iso8601}")
    mtime = Time.now

    response = follow_redirects(url)

    if response.code != '200'
      logger.debug "[IssueTracker#update_issues_github] ##{id} could not connect to github.\nUrl: #{url}\nResponse: #{response.body}"
      return
    end

    return if response.blank?

    parse_github_issues(ActiveSupport::JSON.decode(response.body))

    # we skip callbacks to avoid scheduling expensive jobs
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(issues_updated: mtime - 1.second)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def update_issues_cve
    return unless enable_fetch

    # fixed URL of all entries
    # cveurl = "http://cve.mitre.org/data/downloads/allitems.xml.gz"
    http = Net::HTTP.start('cve.mitre.org')
    header = http.head('/data/downloads/allitems.xml.gz')
    mtime = Time.parse(header['Last-Modified'])

    return unless mtime.nil? || self.issues_updated.nil? || (self.issues_updated < mtime)

    # new file exists
    h = http.get('/data/downloads/allitems.xml.gz')
    unzipedio = StringIO.new(h.body) # Net::HTTP is decompressing already
    listener = CVEparser.new
    listener.set_tracker(self)
    parser = Nokogiri::XML::SAX::Parser.new(listener)
    parser.parse_io(unzipedio)
    # we skip callbacks to avoid scheduling expensive jobs
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(issues_updated: mtime - 1.second)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def update_issues
    # before asking remote to ensure that it is older then on remote, assuming ntp works ...
    # to be sure, just reduce it by 5 seconds (would be nice to have a counter at bugzilla to
    # guarantee a complete search)
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    return update_issues_bugzilla if kind == 'bugzilla'
    return update_issues_github if kind == 'github'
    return update_issues_cve if kind == 'cve'
    false
  end

  # this function is for debugging and disaster recovery
  def enforced_update_all_issues
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    ids = issues.map { |x| x.name.to_s }
    ids.sort! { |x, y| y <=> x } # backward

    if private_fetch_issues(ids)
      # don't use "last_change_time" from bugzilla, since we may have different clocks
      # and skip callbacks to avoid scheduling expensive jobs
      # rubocop:disable Rails/SkipsModelValidations
      update_columns(issues_updated: @update_time_stamp)
      # rubocop:enable Rails/SkipsModelValidations
      return true
    end
    false
  end

  def fetch_issues(issues = nil)
    unless issues
      # find all new issues for myself
      issues = self.issues.stateless
    end

    ids = issues.map { |x| x.name.to_s }

    private_fetch_issues(ids)
  end

  def self.update_all_issues
    IssueTracker.all.find_each do |t|
      next unless t.enable_fetch
      IssueTrackerUpdateIssuesJob.perform_later(t.id)
    end
  end

  private

  def fetch_bugzilla_issues(ids)
    # limit to 256 ids to avoid too much load and timeouts on bugzilla side
    limit_per_slice = 256
    while ids.present?
      begin
        result = bugzilla_server.get({ ids: ids[0..limit_per_slice], permissive: 1 })
      rescue XMLRPC::FaultException => e
        logger.error "Error: #{e.faultCode} #{e.faultString}"
        return false
      rescue StandardError => e
        logger.error "Unable to fetch issue #{e.inspect}"
        return false
      end
      result['bugs'].each { |r| parse_single_bugzilla_issue(r) }
      ids = ids[limit_per_slice..-1]
    end
    true
  end

  def parse_single_bugzilla_issue(bugzilla_response)
    issue = Issue.find_by_name_and_tracker(bugzilla_response['id'].to_s, name)
    return unless issue

    if bugzilla_response['is_open']
      # bugzilla sees it as open
      issue.state = 'OPEN'
    elsif bugzilla_response['is_open'] == false
      # bugzilla sees it as closed
      issue.state = 'CLOSED'
    else
      # bugzilla does not tell a state
      issue.state = Issue.bugzilla_state(bugzilla_response['status'])
    end

    user = User.find_by_email(bugzilla_response['assigned_to'].to_s)
    if user
      issue.owner_id = user.id
    else
      logger.info "Bugzilla user #{bugzilla_response['assigned_to']} is not found in OBS user database"
    end

    if bugzilla_response['creation_time'].present?
      # rubocop:disable Rails/Date
      # rubocop bug, this is XMLRPC/DateTime not Rails/Date
      issue.created_at = bugzilla_response['creation_time'].to_time
    # rubocop:enable Rails/Date
    else
      issue.created_at = Time.now
    end

    # this is our update_at, not the one bugzilla logged in last_change_time
    issue.updated_at = @update_time_stamp
    if bugzilla_response['is_private']
      issue.summary = nil
    else
      issue.summary = bugzilla_response['summary']
    end
    issue.save
  end

  def parse_github_issues(js)
    js.each do |item|
      parse_github_issue(item)
    end
  end

  def parse_github_issue(js, create = nil)
    issue = nil
    begin
      if create
        issue = Issue.find_or_create_by_name_and_tracker(js['number'].to_s, name)
      else
        issue = Issue.find_by_name_and_tracker(js['number'].to_s, name)
        return if issue.nil?
      end
    rescue TypeError
      logger.debug "[IssueTracker#parse_github_issue] cannot parse json response:\n#{js}"
      raise
    end
    if js['state'] == 'open'
      issue.state = 'OPEN'
    else
      issue.state = 'CLOSED'
    end

    issue.updated_at = @update_time_stamp
    issue.summary = js['title']
    issue.save
  end

  def private_fetch_issues(ids)
    unless enable_fetch
      logger.info "Bug mentioned on #{name}, but fetching from server is disabled"
      return false
    end

    return fetch_bugzilla_issues(ids) if kind == 'bugzilla'
    return fetch_github_issues(ids) if kind == 'github'

    # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
    return fetch_fate_issues if kind == 'fate'

    # everything succeeded
    true
  end

  def fetch_fate_issues
    follow_redirects(URI.parse("#{url}/#{name}?contenttype=text%2Fxml"))

    # TODO: Parse returned XML and return proper JSON
    false
  end

  def fetch_github_issues(ids)
    response = nil
    ids.each do |i|
      response = follow_redirects(URI.parse("#{url}/#{i}"))
      next unless response.is_a?(Net::HTTPSuccess)

      parse_github_issue(ActiveSupport::JSON.decode(response.body), true)
    end
  end

  def bugzilla_server
    server = XMLRPC::Client.new2("#{url}/xmlrpc.cgi")
    server.timeout = 300 # 5 minutes timeout
    server.user = user if user
    server.password = password if password
    server.proxy('Bug')
  end

  # helper method that does a GET request to given <url> and follows
  # any redirects.
  #
  # Returns the Net::HTTP response
  def follow_redirects(url)
    response = nil

    loop do
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      request = Net::HTTP::Get.new(url.path)
      response = http.start { |h| h.request(request) }
      url = URI.parse(response.header['location']) if response.header['location']

      break unless response.header['location']
    end

    response
  end
end

# internal CVE parser class
class CVEparser < Nokogiri::XML::SAX::Document
  @@my_tracker = nil
  @@my_issue = nil
  @@my_summary = ''
  @@is_desc = false

  def set_tracker(tracker)
    @@my_tracker = tracker
  end

  def start_element(name, attrs = [])
    if name == 'item'
      cve = nil
      attrs.each_index do |i|
        if attrs[i][0] == 'name'
          cve = attrs[i][1]
        end
      end

      @@my_issue = Issue.find_or_create_by_name_and_tracker(cve.gsub(/^CVE-/, ''), @@my_tracker.name)
      @@my_summary = ''
      @@is_desc = false
    end
    if @@my_issue && name == 'desc'
      @@is_desc = true
    else
      @@is_desc = false
    end
  end

  def characters(content)
    return unless @@is_desc
    @@my_summary += content.chomp
  end

  def end_element(name)
    return unless name == 'item'
    if @@my_summary.present?
      @@my_issue.summary = @@my_summary[0..254]
      @@my_issue.save
    end
    @@my_issue = nil
  end
end

# == Schema Information
#
# Table name: issue_trackers
#
#  id             :integer          not null, primary key
#  name           :string(255)      not null
#  kind           :string(11)       not null
#  description    :string(255)
#  url            :string(255)      not null
#  show_url       :string(255)
#  regex          :string(255)      not null
#  user           :string(255)
#  password       :string(255)
#  label          :text(65535)      not null
#  issues_updated :datetime         not null
#  enable_fetch   :boolean          default(FALSE)
#
