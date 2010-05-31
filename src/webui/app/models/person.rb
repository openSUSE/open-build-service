class Person < ActiveXML::Base
  default_find_parameter :login

  handles_xml_element 'person'
  
  # redefine make_stub so that Person.new( :login => 'login_name' ) works
  class << self
    def make_stub( opt )
      
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
      doc = XML::Document.new
      doc.root = XML::Node.new 'person'
      element = doc.root << 'login'
      element.content = opt[:login]
      element = doc.root << 'realname'
      element.content = realname
      element = doc.root << 'email'
      element.content = email
      element = doc.root << 'state'
      element.content = 5
      doc.root
    end
  end
  
  def to_s
    login.to_s
  end

  def add_watched_project(name)
    return nil unless name
    add_element 'watchlist' unless has_element? :watchlist
    watchlist.add_element 'project', 'name' => name
    logger.debug "user '#{login}' is now watching project '#{name}'"
    Rails.cache.delete("person_#{login}")
  end

  def remove_watched_project(name)
    return nil unless name
    return nil unless watches? name
    watchlist.delete_element "project[@name='#{name}']"
    logger.debug "user '#{login}' removes project '#{name}' from watchlist"
    Rails.cache.delete("person_#{login}")
  end

  def watches?(name)
    has_element?(:watchlist) and watchlist.has_element?("project[@name='#{name}']")
  end

  def involved_projects
    Collection.find_cached :id, :what => 'project', :predicate => %(person/@userid='#{login}')
  end

  def involved_packages
    Collection.find_cached :id, :what => 'package', :predicate => %(person/@userid='#{login}')
  end

  def involved_requests(opts = {})
    opts = {:cache => true}.merge opts

    cachekey = "#{login}_involved_requests"
    Rails.cache.delete cachekey unless opts[:cache]

    requests = Rails.cache.fetch(cachekey, :expires_in => 10.minutes) do
      # we assume that the user is involved in all his subprojects (home:#{login}:...)
      iprojects = involved_projects.each.map {|x| x.name}.reject {|x| /^home:#{login}:/.match(x) }.sort
      requests = Array.new

      unless iprojects.empty?
        predicate = iprojects.map {|item| "action/target/@project='#{item}'"}.join(" or ")
        predicate = "#{predicate} or starts-with(action/target/@project, 'home:#{login}:')"
        predicate = "state/@name='new' and (#{predicate})"
        collection = Collection.find :what => :request, :predicate => predicate
        myrequests = Hash.new
        collection.each do |req| myrequests[Integer(req.value :id)] = req end
        collection = Collection.find :what => :request, :predicate => "state/@name='new' and state/@who='#{login}'"
        collection.each do |req| myrequests[Integer(req.value :id)] = req end
        keys = myrequests.keys().sort {|x,y| y <=> x}
        keys.each {|id| requests << myrequests[id] }
      end
      requests
    end
    return requests
  end

  def packagesorter(a, b)
    a.project == b.project ? a.name <=> b.name : a.project <=> b.project
  end

  def is_admin?
    # FIXME: we should actually ask the backend here
    return true if login.to_s == "Admin"
    return false
  end

  # if package is nil, returns project maintainership
  def is_maintainer?(project, package=nil)
    if package and package.is_maintainer?(login)
      return true
    end
    return project.is_maintainer?(login)
  end
end
