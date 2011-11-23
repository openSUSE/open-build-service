require 'xmlrpc/client'

class IssueTracker < ActiveRecord::Base
  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['', 'other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']

  DEFAULT_RENDER_PARAMS = {:except => :id, :skip_types => true }

  def self.issues_in(text)
    ret = []
    IssueTracker.all.each do |it|
      # Ruby's string#scan method unfortunately doesn't return the whole match if a RegExp contains groups.
      # RegExp#match does that but it doesn't advance the string if called consecutively. Thus we have to do
      # it by hand...
      my_text = text
      begin
        match = it.matches?(my_text)
        if match
          ret << it.issue(match[-1], match[0])
          my_text = my_text[match.end(0)+1..-1]
        end
      end while match
    end
    return ret
  end

  def self.write_to_backend()
    path = "/issue_trackers"
    Suse::Backend.put_source(path, IssueTracker.all.to_xml(DEFAULT_RENDER_PARAMS))
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
    return Issue.new(:name => issue, :long_name => long_name, :issue_tracker => self.name, :description => 'TODO', :show_url => show_url_for(issue))
  end

  def details(issue)
    #NOTE: Experimental code, subject to change, will have caching ;-)
    if kind == "bugzilla"
      # Try with 'IssueTracker.find_by_name('bnc').details('470611')' on script/console
      begin
        server = XMLRPC::Client.new2("#{self.url}/xmlrpc.cgi")
        result = server.proxy('Bug').get(:ids => [issue])
        # TODO: The returned JSON data may be worth filtering
        return result['bugs'][0] if result and result['bugs']
      rescue XMLRPC::FaultException => e
        logger.error "Error: #{e.faultCode} #{e.faultString}"
      end
    elsif kind == "fate"
      # Try with 'IssueTracker.find_by_name('fate').details('123')' on script/console
      url = URI.parse("#{self.url}/#{match[-1]}?contenttype=text%2Fxml")
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
    end
    return {}
  end

end
