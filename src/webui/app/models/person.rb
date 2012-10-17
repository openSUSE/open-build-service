class Person < ActiveXML::Node

  class ListError < Exception; end

  default_find_parameter :login

  handles_xml_element 'person'
  
  # redefine make_stub so that Person.new( :login => 'login_name' ) works
  def self.make_stub( opt )
      
    # stay backwards compatible to old arguments (:name instead of :login)
    if not opt.has_key? :login
      opt[:login] = opt[:name]
    end
    realname = ""
    if opt.has_key? :realname
      realname = opt[:realname]
    end
    email = ""
    if opt.has_key? :email
      email = opt[:email]
    end
    doc = ActiveXML::Node.new '<person/>'
    element = doc.add_element 'login'
    element.text = opt[:login]
    element = doc.add_element 'realname'
    element.text = realname
    element = doc.add_element 'email'
    element.text = email
    element = doc.add_element 'state'
    element.text = 5
    doc
  end
  
  def self.find_cached(login, opts = {})
     if opts.has_key?(:is_current)
       # skip memcache
       Person.free_cache(login, opts)
     end
     super
  end

  def self.email_for_login(person)
    p = Person.find_hashed(person)
    return p["email"] || ''
  end

  def self.realname_for_login(person)
    p = Person.find_hashed(person)
    return p["realname"] || ''
  end

  def initialize(data)
    super(data)
    @login = self.to_hash["login"]
    @groups = nil
    @watched_projects = nil
  end

  def login
    @login
  end

  def to_s
    @login
  end

  def add_watched_project(name)
    return nil unless name
    add_element('watchlist') unless has_element?(:watchlist)
    watchlist.add_element('project', :name => name)
    logger.debug "user '#{login}' is now watching project '#{name}'"
    Rails.cache.delete("person_#{login}_watchlist")
  end

  def remove_watched_project(name)
    return nil unless name
    return nil unless watches? name
    watchlist.delete_element "project[@name='#{name}']"
    logger.debug "user '#{login}' removes project '#{name}' from watchlist"
    Rails.cache.delete("person_#{login}_watchlist")
  end

  def watched_projects
    return @watched_projects if @watched_projects
    watchlist = to_hash["watchlist"]
    if watchlist
      return @watched_projects = watchlist.elements("project").map {|p| p["name"]}.sort {|a,b| a.downcase <=> b.downcase}
    else
      return @watched_projects = []
    end
  end

  def watches?(name)
    return watched_projects.include? name
  end

  def free_cache
    Rails.cache.delete("person_#{login}")
    Rails.cache.delete("person_#{login}_watchlist")
    predicate = "person/@userid='#{login}'"
    groups.each {|group| predicate += " or group/@groupid='#{group}'"}
    Collection.free_cache(:id, :what => 'project', :predicate => predicate)
    Collection.free_cache(:id, :what => 'package', :predicate => predicate)
  end

  def involved_projects
    predicate = "person/@userid='#{login}'"
    groups.each {|group| predicate += " or group/@groupid='#{group}'"}
    Collection.find_cached(:id, :what => 'project', :predicate => predicate)
  end

  def involved_packages
    predicate = "person/@userid='#{login}'"
    groups.each {|group| predicate += " or group/@groupid='#{group}'"}
    Collection.find_cached(:id, :what => 'package', :predicate => predicate)
  end

  # Returns all requests where this user is involved in any way
  def involved_requests(opts = {})
    opts = {:cache => true}.merge opts
    cachekey = "#{login}_involved_requests"
    Rails.cache.delete cachekey unless opts[:cache]
    BsRequest.list(:states => 'new,review', :user => login)
  end

  def running_patchinfos(opts = {})
    cachekey = "#{login}_patchinfos_that_need_work2"
    Rails.cache.delete cachekey unless opts[:cache]
    return Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      array = Array.new
      col = Collection.find_cached(:id, :what => 'package', :predicate => "[kind='patchinfo' and issue/[@state='OPEN' and owner/@login='#{CGI.escape(login)}']]")
      col.each_package do |pi|
        hash = { :package => { :project => pi.project, :name => pi.name } }
        issues = Array.new

        begin
          # get users open issues for package
          path = "/source/#{URI.escape(pi.project)}/#{URI.escape(pi.name)}?view=issues&states=OPEN&login=#{CGI.escape(login)}"
          frontend = ActiveXML::transport
          answer = frontend.direct_http URI(path), :method => "GET"
          doc = ActiveXML::Node.new(answer)
          doc.each("/package/issue") do |s|
            i = {}
            i[:name]= s.find_first("name").text
            i[:tracker]= s.find_first("tracker").text
            i[:label]= s.find_first("label").text
            i[:url]= s.find_first("url").text
            if summary=s.find_first("summary")
              i[:summary] = summary.text
            end
            if state=s.find_first("state")
              i[:state] = state.text
            end
            if login=s.find_first("login")
              i[:login] = login.text
            end
            if updated_at=s.find_first("updated_at")
              i[:updated_at] = updated_at.text
            end
            issues << i
          end

          hash[:issues] = issues
          array << hash
        rescue ActiveXML::Transport::NotFoundError
          # Ugly catch for projects that where deleted while this loop is running... bnc#755463)
        end
      end
      return array
    end
  end

  # Returns a tuple (i.e., array) of open requests and open reviews.
  def requests_that_need_work(opts = {})
    opts = {:cache => true}.merge opts
    cachekey = "#{login}_requests_that_need_work"
    Rails.cache.delete cachekey unless opts[:cache]
    #TODO: make this a xmlhash
    #return Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      [BsRequest.list({:states => 'declined', :roles => "creator", :user => login}),
       BsRequest.list({:states => 'review', :reviewstates => 'new', :roles => "reviewer", :user => login}),
       BsRequest.list({:states => 'new', :roles => "maintainer", :user => login})]
    #end
  end

  def groups
    return @groups if @groups
    @groups = []
    PersonGroup.find(login).to_hash.elements("entry") do |e|
        groups << e['name']
    end
    @groups
  end

  def packagesorter(a, b)
    a.project == b.project ? a.name <=> b.name : a.project <=> b.project
  end

  def is_in_group?(group)
    return groups.include?(group)
  end

  def is_admin?
    to_hash.elements("globalrole").each do |g|  
      return true if g == 'Admin'
    end
    return false
  end

  def is_maintainer?(project, package = nil)
    return has_role?('maintainer', project, package)
  end

  def has_role?(role, project, package = nil)
    if package
      package = Package.find_cached(:project => project, :package => package) if package.class == String
      if package && package.user_has_role?(login, role)
        return true
      end
    end
    project = Project.find_cached(project) if project.class == String
    if project
      return project.user_has_role?(login, role)
    else
      return false
    end
  end

  def self.list(prefix=nil)
    prefix = URI.encode(prefix)
    user_list = Rails.cache.fetch("user_list_#{prefix.to_s}", :expires_in => 10.minutes) do
      transport ||= ActiveXML::transport
      path = "/person?prefix=#{prefix}"
      begin
        logger.debug "Fetching user list from API"
        response = transport.direct_http URI("#{path}"), :method => "GET"
        names = []
        Collection.new(response).each {|user| names << user.name}
        names
      rescue ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ListError, message
      end
    end
    return user_list
  end

end
