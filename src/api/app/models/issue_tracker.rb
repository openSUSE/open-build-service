require 'xmlrpc/client'

class IssueTracker < ApplicationRecord
  has_many :issues, dependent: :destroy

  class NotFoundError < APIError
    setup 'issue_tracker_not_found', 404, 'Issue Tracker not found'
  end

  validates :name, :regex, :url, :kind, presence: true
  validates :name, :regex, uniqueness: { case_sensitive: true }
  validates :kind, inclusion: { in: %w[other bugzilla cve fate trac launchpad sourceforge github jira] }
  validates :description, presence: true
  validates :show_url, presence: true

  after_save :delayed_write_to_backend
  after_save :update_package_meta

  # FIXME: issues_updated should not be hidden, but it should also not break our api
  DEFAULT_RENDER_PARAMS = { except: %i[id password user issues_updated api_key], dasherize: true, skip_types: true, skip_instruct: true }.freeze

  before_validation(on: :create) do
    self.issues_updated ||= Time.now
  end

  # Checks if the given issue belongs to this issue tracker
  #  def matches?(issue)
  #    return Regexp.new(regex).match(issue)
  #  end

  # Generates a URL to display a given issue in the upstream issue tracker
  def show_url_for(issue, html = nil)
    return unless issue

    url = show_url.gsub('@@@', issue)
    if url && kind == 'github'
      url.gsub!(/(github#|gh#)/, '')
      url.gsub!('#', '/issues/')
    end
    return "<a href=\"#{url}\">#{CGI.escapeHTML(show_label_for(issue))}</a>" if html

    url
  end

  def show_label_for(issue)
    label.gsub('@@@', issue)
  end

  def get_markdown(text)
    text.gsub(Regexp.new(regex)) { "[#{Regexp.last_match(0)}](#{show_url_for(Regexp.last_match(1), false)})" }
  end

  def update_issues_github
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
    issues ||= self.issues.stateless

    ids = issues.map { |x| x.name.to_s }

    private_fetch_issues(ids)
  end

  def self.update_all_issues
    IssueTracker.find_each do |t|
      next unless t.enable_fetch

      IssueTrackerUpdateIssuesJob.perform_later(t.id)
    end
  end

  private

  def delayed_write_to_backend
    return unless CONFIG['global_write_through']

    IssueTrackerWriteToBackendJob.perform_later
  end

  def fetch_bugzilla_issues(ids)
    # limit to 64 ids to avoid too much load and timeouts on bugzilla side
    limit_per_slice = 64
    while ids.present?
      begin
        result = bugzilla_server.get(bugzilla_args.merge(ids: ids[0..limit_per_slice], permissive: 1))
      rescue XMLRPC::FaultException => e
        logger.error "Error: #{e.faultCode} #{e.faultString}"
        return false
      rescue StandardError => e
        logger.error "Unable to fetch issue #{e.inspect}"
        return false
      end
      result['bugs'].each { |r| parse_single_bugzilla_issue(r) }
      ids = ids[limit_per_slice..]
    end
    true
  end

  def parse_single_bugzilla_issue(bugzilla_response)
    issue = Issue.find_by_name_and_tracker(bugzilla_response['id'].to_s, name)
    return unless issue

    issue.state = if bugzilla_response['is_open']
                    # bugzilla sees it as open
                    'OPEN'
                  elsif bugzilla_response['is_open'] == false
                    # bugzilla sees it as closed
                    'CLOSED'
                  else
                    # bugzilla does not tell a state
                    Issue.bugzilla_state(bugzilla_response['status'])
                  end

    user = User.find_by_email(bugzilla_response['assigned_to'].to_s)
    if user
      issue.owner_id = user.id
    else
      issue.owner_id = nil
      logger.info "Bugzilla user #{bugzilla_response['assigned_to']} is not found in OBS user database"
    end

    issue.created_at = if bugzilla_response['creation_time'].present?
                         bugzilla_response['creation_time'].to_time
                       else
                         Time.now
                       end

    # this is our update_at, not the one bugzilla logged in last_change_time
    issue.updated_at = @update_time_stamp
    issue.summary = if bugzilla_response['is_private']
                      nil
                    else
                      bugzilla_response['summary']
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
    issue.state = if js['state'] == 'open'
                    'OPEN'
                  else
                    'CLOSED'
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

  def bugzilla_args
    return {} if api_key.blank?

    { 'Bugzilla_login' => user, 'Bugzilla_api_key' => api_key }
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

  def update_issues_bugzilla
    begin
      result = bugzilla_server.search(bugzilla_args.merge(last_change_time: self.issues_updated))
    rescue Net::ReadTimeout, Errno::ECONNRESET
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

  def update_issues_cve
    # fixed URL of all entries
    # cveurl = "https://cve.mitre.org/data/downloads/allitems.xml.gz"
    http = Net::HTTP.start('cve.mitre.org', use_ssl: true)
    header = http.head('/data/downloads/allitems.xml.gz')
    mtime = Time.parse(header['Last-Modified'])

    return unless mtime.nil? || self.issues_updated.nil? || (self.issues_updated < mtime)

    # new file exists
    h = http.get('/data/downloads/allitems.xml.gz')
    unzipedio = StringIO.new(h.body) # Net::HTTP is decompressing already
    listener = IssueTracker::CVEParser.new
    listener.tracker = self
    parser = Nokogiri::XML::SAX::Parser.new(listener)
    parser.parse_io(unzipedio)
    # we skip callbacks to avoid scheduling expensive jobs
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(issues_updated: mtime - 1.second)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def update_package_meta
    return unless CONFIG['global_write_through']

    # We need to parse again ALL sources ...
    UpdatePackageMetaJob.perform_later
  end
end

# == Schema Information
#
# Table name: issue_trackers
#
#  id             :integer          not null, primary key
#  api_key        :string(255)
#  description    :string(255)
#  enable_fetch   :boolean          default(FALSE)
#  issues_updated :datetime         not null
#  kind           :string           not null
#  label          :text(65535)      not null
#  name           :string(255)      not null
#  password       :string(255)
#  publish_issues :boolean          default(TRUE)
#  regex          :string(255)      not null
#  show_url       :string(8192)
#  url            :string(255)      not null
#  user           :string(255)
#
