require 'xmlrpc/client'
require 'opensuse/backend'

class IssueTracker < ActiveRecord::Base
  has_many :issues, :dependent => :destroy

  class UnknownObjectError < Exception; end

  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['', 'other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']

  DEFAULT_RENDER_PARAMS = {:except => [:id, :password, :user], :skip_types => true }

  def self.issues_in(text, diff_mode = false)
    ret = []
    if diff_mode
      old_issues, new_issues = [], []
    end
    # Ruby's string#scan method unfortunately doesn't return the whole match if a RegExp contains groups.
    # RegExp#match does that but it doesn't advance the string if called consecutively. Thus we have to do
    # it by hand...
    text.lines.each do |line|
      IssueTracker.all.each do |it|
        substr = line
        begin
          match = it.matches?(substr)
          if match
            issue = Issue.find_or_create_by_name(match[-1], :issue_tracker => it, :long_name => match[0])
            if diff_mode
              old_issues << issue if line.starts_with?('-')
              new_issues << issue if line.starts_with?('+')
            else
              ret << issue
            end
            substr = substr[match.end(0)+1..-1]
          end
        end while match
      end
    end
    if diff_mode
      old_issue_names, new_issue_names = old_issues.map{|i| i.long_name}, new_issues.map{|i| i.long_name}

      old_issues.each do |old_issue|
        ret << old_issue if not new_issue_names.include?(old_issue.long_name)
      end
      new_issues.each do |new_issue|
        ret << new_issue if not old_issue_names.include?(new_issue.long_name)
      end
    end
    return ret.sort {|a, b| a.long_name <=> b.long_name}
  end

  def self.write_to_backend()
    path = "/issue_trackers"
    logger.debug "Write issue tracker information to backend..."
    Suse::Backend.put_source(path, IssueTracker.all.to_xml(DEFAULT_RENDER_PARAMS))
  end

  def self.get_by_name(name)
    tracker = self.find_by_name(name)
    raise UnknownObjectError unless tracker
    return tracker
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

  def issue(issue, long_name = nil)
    return Issue.find_or_create_by_id(issue.id, :issue_tracker => self, :long_name => long_name)
  end

  def fetch_issues(issues=nil)
    unless issues
      # find all new issues for myself
      issues = Issue.find :all, :conditions => ["(ISNULL(state) or ISNULL(owner_id)) and issue_tracker_id = BINARY ?", self.id]
    end

    return unless issues

    if kind == "bugzilla"
      # the performent way, but bugzilla errors out when one of them is missing/not readable
      # result = bugzilla_server.get(:ids => issues.map{ |x| x.name.to_s })
      # So creating more load here for bugzilla
      issues.each do |i|
        begin
          result = bugzilla_server.get(:ids => [i.name.to_s])
          result["bugs"].each{ |r|
            issue = nil
            issues.each{ |ui|
              if ui["name"].to_s == r["id"].to_s
                issue = ui
                break
              end
            }
            if issue
              issue.state = r["status"]
              u = User.find_by_email(r["assigned_to"].to_s)
              issue.owner_id = u.id if u
              issue.description = r["summary"] # FIXME2.3 check for internal only bugs here
              issue.save
            end
          }
        rescue RuntimeError => e
          logger.error "Unable to fetch issue #{i.name}: #{e.inspect}"
        rescue XMLRPC::FaultException => e
          logger.error "Error: #{e.faultCode} #{e.faultString}"
        end
      end
    elsif kind == "fate"
      # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
      url = URI.parse("#{self.url}/#{self.name}?contenttype=text%2Fxml")
      begin # Need a loop to follow redirects...
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')
        request = Net::HTTP::Get.new(url.path)
        resp = http.start {|http| http.request(request) }
        url = URI.parse(resp.header['location']) if resp.header['location']
      end while resp.header['location']
      # TODO: Parse returned XML and return proper JSON
      return resp.body
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
      end
    elsif kind == "cve"
      # FIXME: add support
    end
  end

  private
  def bugzilla_server
    server = XMLRPC::Client.new2("#{self.url}/xmlrpc.cgi", user=self.user, password=self.password)
    return server.proxy('Bug')
  end

end
