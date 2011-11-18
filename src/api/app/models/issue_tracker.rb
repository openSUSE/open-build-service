require 'xmlrpc/client'

class IssueTracker < ActiveRecord::Base
  validates_presence_of :name, :regex, :url
  validates_uniqueness_of :name, :regex
  validates_inclusion_of :kind, :in => ['', 'other', 'bugzilla', 'cve', 'fate', 'trac', 'launchpad', 'sourceforge']

  # Provides a list of all regexen for all issue trackers
  def self.regexen
    # TODO: The next line is perfectly cacheable, only needs invalidation if any issue track
    return IssueTracker.all.map {|it| Regexp.new(it.regex)}
  end

  # Checks if the given issue belongs to this issue tracker
  def matches?(issue)
    return Regexp.new(regex).match(issue)
  end

  # Generates a URL to display a given issue in the upstream issue tracker
  def show_url_for(issue)
    match = matches?(issue)
    # Always use the last capture group for the upstream part (i.e. the '1234' in 'bnc#1234')
    return show_url.gsub('@@@', match[-1]) if match
    return nil
  end

  def details(issue)
    #NOTE: Experimental code, subject to change
    match = matches?(issue)
    if match
      if kind == "bugzilla"
        # Try with 'IssueTracker.find_by_name('bnc').details('bnc#470611')' on script/console
        begin
          server = XMLRPC::Client.new2("#{self.url}/xmlrpc.cgi")
          result = server.proxy('Bug').get(:ids => [match[-1]])
          # TODO: The returned JSON data may be worth filtering
          return result['bugs'][0] if result and result['bugs']
        rescue XMLRPC::FaultException => e
          logger.error "Error: #{e.faultCode} #{e.faultString}"
        end
      elsif kind == "fate"
        # Try with 'IssueTracker.find_by_name('fate').details('fate#123')' on script/console
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
      elsif kind == "cve"
        # TODO: Probably hardest of all, is there any common API to CVE trackers?!?
      elsif kind == "launchpad"
        # TODO:
      elsif kind == "sourceforge"
        # TODO:
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
    end
    return {}
  end
end
