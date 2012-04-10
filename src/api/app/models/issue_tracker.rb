require 'xmlrpc/client'
require 'opensuse/backend'

class IssueTracker < ActiveRecord::Base
  has_many :issues, :dependent => :destroy

  class UnknownObjectError < Exception; end

  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['', 'other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']

  attr_accessible :name, :kind, :description, :regex, :label, :url, :enable_fetch, :issues_updated, :show_url

  # FIXME: issues_updated should not be hidden, but it should also not break our api
  DEFAULT_RENDER_PARAMS = {:except => [:id, :password, :user, :issues_updated], :dasherize => true, :skip_types => true, :skip_instruct => true }

  def self.write_to_backend()
    path = "/issue_trackers"
    logger.debug "Write issue tracker information to backend..."
    Suse::Backend.put_source(path, IssueTracker.all.to_xml(DEFAULT_RENDER_PARAMS))

    # We need to parse again ALL sources ...
    IssueTracker.first.delay.update_package_metadata
  end

  before_validation(:on => :create) do
    self.issues_updated ||= Time.now
  end

  def update_package_metadata
    DbProject.each do |prj|
      next unless DbProject.exists?(prj)
      prj.db_packages.each do |pkg|
        next unless DbPackage.exists?(pkg)
        begin
          pkg.set_package_kind
        rescue Suse::Backend::HTTPError
        end
      end
    end
  end

  # Checks if the given issue belongs to this issue tracker
  def matches?(issue)
    return Regexp.new(regex).match(issue)
  end

  # Generates a URL to display a given issue in the upstream issue tracker
  def show_url_for(issue)
    return show_url.gsub('@@@', issue) if issue
    return nil
  end

  def issue(issue_id)
    return Issue.find_by_name_and_tracker(issue_id, self.name)
  end

  def update_issues()
    # before asking remote to ensure that it is older then on remote, assuming ntp works ...
    # to be sure, just reduce it by 5 seconds (would be nice to have a counter at bugzilla to 
    # guarantee a complete search)
    update_time_stamp = Time.at(Time.now.to_f - 5)

    if kind == "bugzilla"
      result = bugzilla_server.search(:last_change_time => self.issues_updated)
      ids = result["bugs"].map{ |x| x["id"].to_i }

      if private_fetch_issues(ids)
        self.issues_updated = update_time_stamp
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

  # this function is usually never called. Just for debugging and disaster recovery
  def enforced_update_all_issues()
    update_time_stamp = Time.at(Time.now.to_f - 5)

    ids = issues.map{ |x| x.name.to_s }

    if private_fetch_issues(ids)
      self.issues_updated = update_time_stamp
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

    ids = issues.map{ |x| x.name.to_s }

    return private_fetch_issues(ids)
  end

  private
  def private_fetch_issues(ids)
    unless self.enable_fetch
     logger.info "Bug mentioned on #{self.name}, but fetching from server is disabled"
     return false
    end

    update_time_stamp = Time.at(Time.now.to_f)

    if kind == "bugzilla"
      # limit to 256 ids to avoid too much load and timeouts on bugzilla side
      limit_per_slice=256
      while ids
        begin
          result = bugzilla_server.get({:ids => ids[0..limit_per_slice], :permissive => 1})
        rescue RuntimeError => e
          logger.error "Unable to fetch issue #{e.inspect}"
          return false
        rescue XMLRPC::FaultException => e
          logger.error "Error: #{e.faultCode} #{e.faultString}"
          return false
        end
        result["bugs"].each{ |r|
          issue = Issue.find_by_name_and_tracker r["id"].to_s, self.name
          if issue
            if r["is_open"]
              # bugzilla sees it as open
              issue.state = Issue.states["OPEN"]
            elsif r["is_open"] == false
              # bugzilla sees it as closed
              issue.state = Issue.states["CLOSED"]
            else
              # bugzilla does not tell a state
              issue.state = Issue.bugzilla_state(r["status"])
            end
            u = User.find_by_email(r["assigned_to"].to_s)
            logger.info "Bug user #{r["assigned_to"].to_s} is not found in OBS user database" unless u
            issue.owner_id = u.id if u
            issue.updated_at = update_time_stamp
            if r["is_private"]
              issue.summary = nil
            else
              issue.summary = r["summary"]
            end
            issue.save
          end
        }

        ids=ids[limit_per_slice..-1]
      end
    elsif kind == "fate"
      # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
      url = URI.parse("#{self.url}/#{self.name}?contenttype=text%2Fxml")
      begin # Need a loop to follow redirects...
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')
        request = Net::HTTP::Get.new(url.path)
        resp = http.start {|h| h.request(request) }
        url = URI.parse(resp.header['location']) if resp.header['location']
      end while resp.header['location']
      # TODO: Parse returned XML and return proper JSON
      return false
    elsif kind == "trac"
      # TODO: Most trac instances demand a login, maybe worth having one ;-)
      server = XMLRPC::Client.new2("#{self.url}/rpc")
      begin
        server.proxy('system').listMethods()
      rescue XMLRPC::FaultException => e
        logger.error "Error: #{e.faultCode} #{e.faultString}"
        if e.faultCode == 403
          # The url would be http://user:pass@trac-inst.com/login/rpc
          #server = XMLRPC::Client.new2("#{self.url}/login/rpc")
        end
        return false
      end
    end
    # everything succeeded
    return true
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

