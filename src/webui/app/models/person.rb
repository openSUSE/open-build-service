class Person < ActiveXML::Base

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
    doc = ActiveXML::Base.new '<person/>'
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
  
  @@person_cache = Hash.new
  def self.clean_cache
    @@person_cache.clear
  end

  def self.find_cached(login, opts = {})
     if opts.has_key?(:is_current)
       # skip memcache
       @@person_cache[login] = Person.find login
     end
     if @@person_cache.has_key? login
       return @@person_cache[login]
     end
     @@person_cache[login] = super
  end

  def self.email_for_login(person)
    p = Person.find_cached(person)
    return p.value(:email) if p
    return ''
  end

  def self.realname_for_login(person)
    p = Person.find_cached(person)
    return p.value(:realname) if p
    return ''
  end

  def initialize(data)
    @mygroups = nil
    super(data)
    @login = self.value(:login)
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
    @@person_cache.delete(login)
    Rails.cache.delete("person_#{login}_watchlist")
  end

  def remove_watched_project(name)
    return nil unless name
    return nil unless watches? name
    watchlist.delete_element "project[@name='#{name}']"
    logger.debug "user '#{login}' removes project '#{name}' from watchlist"
    @@person_cache.delete(login)
    Rails.cache.delete("person_#{login}_watchlist")
  end

  def watched_projects
    if has_element?(:watchlist)
      return Rails.cache.fetch("person_#{login}_watchlist") do
        watchlist.each_project.map {|p| p.name}.sort {|a,b| a.downcase <=> b.downcase}
      end
    else
      return {}
    end
  end

  def watches?(name)
    has_element?(:watchlist) and watchlist.has_element?("project[@name='#{name}']")
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
    return Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      BsRequest.list(:states => 'new,review', :user => login.to_s)
    end
  end

  def running_patchinfos(opts = {})
    cachekey = "#{login}_patchinfos_that_need_work"
    Rails.cache.delete cachekey unless opts[:cache]
    return Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      Collection.find_cached(:id, :what => 'package', :predicate => "[kind='patchinfo' and issue/[@state='OPEN' and owner/@login='#{login}']]")
    end
  end

  # Returns a tuple (i.e., array) of open requests and open reviews.
  def requests_that_need_work(opts = {})
    opts = {:cache => true}.merge opts
    cachekey = "#{login}_requests_that_need_work"
    Rails.cache.delete cachekey unless opts[:cache]
    return Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      [BsRequest.list({:states => 'declined', :roles => "creator", :user => login.to_s}),
       BsRequest.list({:states => 'review', :reviewstates => 'new', :roles => "reviewer", :user => login.to_s}),
       BsRequest.list({:states => 'new', :roles => "maintainer", :user => login.to_s})]
    end
  end

  def groups
    return @mygroups if @mygroups
    @mygroups = Array.new
    PersonGroup.find(login.to_s).each('/directory/entry') do |e|
        @mygroups << e.value("name")
    end
    return @mygroups
  end

  def packagesorter(a, b)
    a.project == b.project ? a.name <=> b.name : a.project <=> b.project
  end

  def is_in_group?(group)
    return groups.include?(group)
  end

  def is_admin?
    has_element?( "globalrole[text() = \"Admin\"]" )
  end

  def is_maintainer?(project, package = nil)
    return has_role?('maintainer', project, package)
  end

  def has_role?(role, project, package = nil)
    if package
      package = Package.find_cached(:project => project, :package => package) if package.class == String
      return true if package.user_has_role?(login, role)
    end
    project = Project.find_cached(project) if project.class == String
    return project.user_has_role?(login, role)
  end

  def self.list(prefix=nil)
    prefix = URI.encode(prefix)
    user_list = Rails.cache.fetch("user_list_#{prefix.to_s}", :expires_in => 10.minutes) do
      transport ||= ActiveXML::Config::transport_for(:person)
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
