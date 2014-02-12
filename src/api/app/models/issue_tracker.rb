require 'xmlrpc/client'
require 'opensuse/backend'

class IssueTracker < ActiveRecord::Base
  has_many :issues, :dependent => :destroy

  class NotFoundError < APIException
    setup 'issue_tracker_not_found', 404, "Issue Tracker not found"
  end

  validates_presence_of :name, :regex, :url, :kind
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => %w(other bugzilla cve fate trac launchpad sourceforge)

  # FIXME: issues_updated should not be hidden, but it should also not break our api
  DEFAULT_RENDER_PARAMS = {:except => [:id, :password, :user, :issues_updated], :dasherize => true, :skip_types => true, :skip_instruct => true}

  def self.write_to_backend
    IssueTracker.first.delay.write_to_backend
  end

  def write_to_backend
    path = "/issue_trackers"
    logger.debug "Write issue tracker information to backend..."
    Suse::Backend.put_source(path, IssueTracker.all.to_xml(DEFAULT_RENDER_PARAMS))

    # We need to parse again ALL sources ...
    UpdatePackageMetaJob.new.delay.perform
  end

  before_validation(:on => :create) do
    self.issues_updated ||= Time.now
  end

  # Checks if the given issue belongs to this issue tracker
  #  def matches?(issue)
  #    return Regexp.new(regex).match(issue)
  #  end

  # Generates a URL to display a given issue in the upstream issue tracker
  #  def show_url_for(issue)
  #    return show_url.gsub('@@@', issue) if issue
  #    return nil
  #  end

  #  def issue(issue_id)
  #    return Issue.find_by_name_and_tracker(issue_id, self.name)
  #  end

  def update_issues
    # before asking remote to ensure that it is older then on remote, assuming ntp works ...
    # to be sure, just reduce it by 5 seconds (would be nice to have a counter at bugzilla to 
    # guarantee a complete search)
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    if kind == "bugzilla"
      begin
        result = bugzilla_server.search(:last_change_time => self.issues_updated)
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
        self.save!

        return true
      end
    elsif kind == "cve"
      if self.enable_fetch
        # fixed URL of all entries
        # cveurl = "http://cve.mitre.org/data/downloads/allitems.xml.gz"
        http = Net::HTTP.start("cve.mitre.org")
        header = http.head("/data/downloads/allitems.xml.gz")
        mtime = Time.parse(header["Last-Modified"])
        if mtime.nil? or self.issues_updated.nil? or (self.issues_updated < mtime)
          # new file exists
          h = http.get("/data/downloads/allitems.xml.gz")
          unzipedio = Zlib::GzipReader.new(StringIO.new(h.body))
          listener = CVEparser.new()
          listener.set_tracker(self)
          parser = Nokogiri::XML::SAX::Parser.new(listener)
          parser.parse_io(unzipedio)
          # done
          self.issues_updated = mtime
          self.save
        end
        return true
      end
    end
    return false
  end

  # this function is for debugging and disaster recovery
  def enforced_update_all_issues
    @update_time_stamp = Time.at(Time.now.to_f - 5)

    ids = issues.map { |x| x.name.to_s }
    ids.sort! { |x,y| y <=> x } # backward

    if private_fetch_issues(ids)
      self.issues_updated = @update_time_stamp
      self.save!
      return true
    end
    return false
  end

  def fetch_issues(issues=nil)
    unless issues
      # find all new issues for myself
      issues = self.issues.stateless
    end

    ids = issues.map { |x| x.name.to_s }

    return private_fetch_issues(ids)
  end

  def self.update_all_issues
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.delay.update_issues
    end
  end

  private

  def fetch_bugzilla_issues(ids)
    # limit to 256 ids to avoid too much load and timeouts on bugzilla side
    limit_per_slice=256
    while !ids.blank?
      begin
        result = bugzilla_server.get({:ids => ids[0..limit_per_slice], :permissive => 1})
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
    return true
  end

  def parse_single_bugzilla_issue(r)
    issue = Issue.find_by_name_and_tracker r["id"].to_s, self.name
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
      logger.info "Bugzilla user #{r["assigned_to"].to_s} is not found in OBS user database" unless u
      issue.owner_id = u.id if u
      issue.updated_at = @update_time_stamp
      if r["is_private"]
        issue.summary = nil
      else
        issue.summary = r["summary"]
      end
      issue.save
    end
  end

  def private_fetch_issues(ids)
    unless self.enable_fetch
      logger.info "Bug mentioned on #{self.name}, but fetching from server is disabled"
      return false
    end

    if kind == "bugzilla"
      return fetch_bugzilla_issues(ids)
    elsif kind == "fate"
      # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
      return fetch_fate_issues
    end
    # everything succeeded
    return true
  end

  def fetch_fate_issues
    url = URI.parse("#{self.url}/#{self.name}?contenttype=text%2Fxml")
    begin # Need a loop to follow redirects...
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      request = Net::HTTP::Get.new(url.path)
      resp = http.start { |h| h.request(request) }
      url = URI.parse(resp.header['location']) if resp.header['location']
    end while resp.header['location']
    # TODO: Parse returned XML and return proper JSON
    return false
  end

  def bugzilla_server
    server = XMLRPC::Client.new2("#{self.url}/xmlrpc.cgi")
    server.timeout = 300 # 5 minutes timeout
    server.user=self.user if self.user
    server.password=self.password if self.password
    return server.proxy('Bug')
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

  def start_element(name, attrs=[])
    if name == "item"
      cve=nil
      attrs.each_index do |i|
        if attrs[i][0] == "name"
          cve = attrs[i][1]
        end
      end

      #@@myIssue = Issue.find_or_create_by_name_and_tracker(cve, @@myTracker.name)
      @@myIssue = Issue.find_by_name_and_tracker cve, @@myTracker.name
      @@mySummary = ""
      @@isDesc = false
    end
    if @@myIssue and name == "desc"
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
      @@myIssue.summary = @@mySummary
      @@myIssue.save
    end
    @@myIssue = nil
  end
end

