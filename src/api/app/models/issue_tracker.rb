require 'xmlrpc/client'
require 'opensuse/backend'

class IssueTracker < ApplicationRecord
  has_many :issues, dependent: :destroy

  class NotFoundError < APIException
    setup 'issue_tracker_not_found', 404, "Issue Tracker not found"
  end
  class InvalidIssueName < APIException; end

  validates_presence_of :name, :regex, :url, :kind
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, in: %w(other bugzilla cve fate trac launchpad sourceforge github)

  # FIXME: issues_updated should not be hidden, but it should also not break our api
  DEFAULT_RENDER_PARAMS = {except: [:id, :password, :user, :issues_updated], dasherize: true, skip_types: true, skip_instruct: true}

  def self.write_to_backend
    IssueTracker.first.delay.write_to_backend
  end

  def write_to_backend
    path = "/issue_trackers"
    logger.debug "Write issue tracker information to backend..."
    Suse::Backend.put_source(path, IssueTracker.all.to_xml(DEFAULT_RENDER_PARAMS))

    # We need to parse again ALL sources ...
    UpdatePackageMetaJob.perform_later
  end

  before_validation(on: :create) do
    self.issues_updated ||= Time.now
  end

  def cve?
    kind == "cve"
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
    return nil unless issue
    url = show_url.gsub('@@@', issue)
    return "<a href=\"#{url}\">#{CGI::escapeHTML(show_label_for(issue))}</a>" if html
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
    ids = result["bugs"].map { |x| x["id"].to_i }

    if private_fetch_issues(ids)
      self.issues_updated = @update_time_stamp
      save!

      return true
    end
  end

  def update_issues_github
    return unless enable_fetch

    # must be like this "url = https://github.com/repos/#{self.owner}/#{self.name}/issues"
    url = URI.parse("#{self.url}?since=#{self.issues_updated.to_time.iso8601}")
    mtime = Time.now
    begin # Need a loop to follow redirects...
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      request = Net::HTTP::Get.new(url.path)
      response = http.start { |h| h.request(request) }
      url = URI.parse(response.header['location']) if response.header['location']
    end while response.header['location']
    return nil if response.blank?
    parse_github_issues(ActiveSupport::JSON.decode(response.body))

    # done
    self.issues_updated = mtime - 1.second
    save
  end

  def update_issues_cve
    return unless enable_fetch

    # fixed URL of all entries
    # cveurl = "http://cve.mitre.org/data/downloads/allitems.xml.gz"
    http = Net::HTTP.start("cve.mitre.org")
    header = http.head("/data/downloads/allitems.xml.gz")
    mtime = Time.parse(header["Last-Modified"])
    if mtime.nil? || self.issues_updated.nil? || (self.issues_updated < mtime)
      # new file exists
      h = http.get("/data/downloads/allitems.xml.gz")
      unzipedio = StringIO.new(h.body) # Net::HTTP is decompressing already
      listener = CVEparser.new()
      listener.set_tracker(self)
      parser = Nokogiri::XML::SAX::Parser.new(listener)
      parser.parse_io(unzipedio)
      # done
      self.issues_updated = mtime - 1.second
      save
    end
  end

  def update_issues
    # before asking remote to ensure that it is older then on remote, assuming ntp works ...
    # to be sure, just reduce it by 5 seconds (would be nice to have a counter at bugzilla to
    # guarantee a complete search)
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    return update_issues_bugzilla if kind == "bugzilla"
    return update_issues_github if kind == "github"
    return update_issues_cve if kind == "cve"
    false
  end

  # this function is for debugging and disaster recovery
  def enforced_update_all_issues
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    ids = issues.map { |x| x.name.to_s }
    ids.sort! { |x, y| y <=> x } # backward

    if private_fetch_issues(ids)
      # don't use "last_change_time" from bugzilla, since we may have different clocks
      self.issues_updated = @update_time_stamp
      save!
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
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.delay(queue: "issuetracking").update_issues
    end
  end

  private

  def fetch_bugzilla_issues(ids)
    # limit to 256 ids to avoid too much load and timeouts on bugzilla side
    limit_per_slice=256
    while !ids.blank?
      begin
        result = bugzilla_server.get({ids: ids[0..limit_per_slice], permissive: 1})
      rescue RuntimeError => e
        logger.error "Unable to fetch issue #{e.inspect}"
        return false
      rescue XMLRPC::FaultException => e
        logger.error "Error: #{e.faultCode} #{e.faultString}"
        return false
      end
      result["bugs"].each { |r| parse_single_bugzilla_issue(r) }
      ids=ids[limit_per_slice..-1]
    end
    true
  end

  def parse_single_bugzilla_issue(r)
    issue = Issue.find_by_name_and_tracker r["id"].to_s, name
    if issue
      if r["is_open"]
        # bugzilla sees it as open
        issue.state = "OPEN"
      elsif r["is_open"] == false
        # bugzilla sees it as closed
        issue.state = "CLOSED"
      else
        # bugzilla does not tell a state
        issue.state = Issue.bugzilla_state(r["status"])
      end
      u = User.find_by_email(r["assigned_to"].to_s)
      logger.info "Bugzilla user #{r["assigned_to"]} is not found in OBS user database" unless u
      issue.owner_id = u.id if u
      issue.created_at = r["creation_time"]
      # this is our update_at, not the one bugzilla logged in last_change_time
      issue.updated_at = @update_time_stamp
      if r["is_private"]
        issue.summary = nil
      else
        issue.summary = r["summary"]
      end
      issue.save
    end
  end

  def parse_github_issues(js)
    js.each do |item|
      parse_github_issue(item)
    end
  end

  def parse_github_issue(js, create = nil)
      issue = nil
      if create
        issue = Issue.find_or_create_by_name_and_tracker(js["number"].to_s, name)
      else
        issue = Issue.find_by_name_and_tracker(js["number"].to_s, name)
        return if issue.nil?
      end

      if js["state"] == "open"
        issue.state = "OPEN"
      else
        issue.state = "CLOSED"
      end
#      u = User.find_by_email(js["assignee"]["login"].to_s)
      issue.updated_at = @update_time_stamp
      issue.summary = js["title"]
      issue.save
  end

  def private_fetch_issues(ids)
    unless enable_fetch
      logger.info "Bug mentioned on #{name}, but fetching from server is disabled"
      return false
    end

    if kind == "bugzilla"
      return fetch_bugzilla_issues(ids)
    elsif kind == "github"
      return fetch_github_issues(ids)
    elsif kind == "fate"
      # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
      return fetch_fate_issues
    end
    # everything succeeded
    true
  end

  def fetch_fate_issues
    url = URI.parse("#{self.url}/#{name}?contenttype=text%2Fxml")
    begin # Need a loop to follow redirects...
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      request = Net::HTTP::Get.new(url.path)
      resp = http.start { |h| h.request(request) }
      url = URI.parse(resp.header['location']) if resp.header['location']
    end while resp.header['location']
    # TODO: Parse returned XML and return proper JSON
    false
  end

  def fetch_github_issues(ids)
    response = nil
    ids.each do |i|
      url = URI.parse("#{self.url}/#{i}")
      begin # Need a loop to follow redirects...
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')
        request = Net::HTTP::Get.new(url.path)
        response = http.start { |h| h.request(request) }
        url = URI.parse(response.header['location']) if response.header['location']
      end while response.header['location']
      next unless response.is_a?(Net::HTTPSuccess)
      parse_github_issue(ActiveSupport::JSON.decode(response.body), true)
    end
  end

  def bugzilla_server
    server = XMLRPC::Client.new2("#{url}/xmlrpc.cgi")
    server.timeout = 300 # 5 minutes timeout
    server.user=user if user
    server.password=password if password
    server.proxy('Bug')
  end
end

# internal CVE parser class
class CVEparser < Nokogiri::XML::SAX::Document
  @@myTracker = nil
  @@myIssue = nil
  @@mySummary = ""
  @@isDesc = false

  def set_tracker(tracker)
    @@myTracker = tracker
  end

  def start_element(name, attrs = [])
    if name == "item"
      cve=nil
      attrs.each_index do |i|
        if attrs[i][0] == "name"
          cve = attrs[i][1]
        end
      end

      @@myIssue = Issue.find_or_create_by_name_and_tracker(cve.gsub(/^CVE-/, ''), @@myTracker.name)
      @@mySummary = ""
      @@isDesc = false
    end
    if @@myIssue && name == "desc"
      @@isDesc=true
    else
      @@isDesc=false
    end
  end

  def characters(content)
    if @@isDesc
      @@mySummary += content.chomp
    end
  end

  def end_element(name)
    return unless name == "item"
    unless @@mySummary.blank?
      @@myIssue.summary = @@mySummary[0..254]
      @@myIssue.save
    end
    @@myIssue = nil
  end
end
