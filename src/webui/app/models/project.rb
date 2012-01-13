class Project < ActiveXML::Base
  
  default_find_parameter :name

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  #cache variables
  attr_accessor :my_repositories, :my_repo_hash
  attr_accessor :my_architectures

  handles_xml_element 'project'

  class Repository < ActiveXML::XMLNode
    handles_xml_element 'repository'

    def archs
      @archs ||= each_arch.map {|a| a.to_s}
      return @archs
    end

    def archs=(new_archs)
      new_archs.map! {|a| a.to_s}
      archs.reject {|a| new_archs.include?(a)}.each {|arch| remove_arch(arch)}
      new_archs.reject {|a| archs.include?(a)}.each {|arch| add_arch(arch)}
    end

    def add_arch(arch)
      return nil if archs.include? arch
      @archs.push arch
      e = add_element('arch')
      e.text = arch
    end

    def remove_arch(arch)
      return nil unless archs.include? arch
      each_arch do |a|
        delete_element(a) if a.text == arch
      end
      @archs.delete arch
    end

    def paths
      @paths ||= each_path.map {|p| p.project + '/' + p.repository}
      return @paths
    end

    def paths=(new_paths)
      paths.clone.each {|path| remove_path(path)}
      new_paths.each {|path| add_path(path)}
    end

    def add_path(path)
      return nil if paths.include? path
      project, repository = path.split("/")
      @paths.push path
      e = add_element('path')
      e.set_attribute('repository', repository)
      e.set_attribute('project', project)
    end

    def remove_path(path)
      return nil unless paths.include? path
      project, repository = path.split("/")
      delete_element "//path[@project='#{project.to_xs}' and @repository='#{repository.to_xs}']"
      @paths.delete path
    end

    # directions are :up and :down
    def move_path(path, direction=:up)
      return nil unless (path and not paths.empty?)
      new_paths = paths.clone
      for i in 0..new_paths.length
        if new_paths[i] == path           # found the path to move?
          if direction == :up and i != 0  # move up and is not the first?
            new_paths[i - 1], new_paths[i] = new_paths[i], new_paths[i - 1]
            paths=(new_paths) and break
          elsif direction == :down and i != new_paths.length - 1
            new_paths[i + 1], new_paths[i] = new_paths[i], new_paths[i + 1]
            paths=(new_paths) and break
          end
        end
      end
    end
  end

  #check if named project exists
  def self.exists?(pro_name)
    return true if Project.find pro_name
    return false
  end
  
  #check if named project comes from a remote OBS instance
  def self.is_remote?(pro_name)
    p = Project.find pro_name
    return true if p && p.has_element?(:mountproject)
    return false
  end
  
  def to_s
    name.to_s
  end

  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to project #{self.name}"

    add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]
  end

  def add_group(opt={})
    return false unless opt[:groupid] and opt[:role]
    logger.debug "adding group '#{opt[:groupid]}', role '#{opt[:role]}' to project #{self.name}"

    # add the new group
    add_element 'group', 'groupid' => opt[:groupid], 'role' => opt[:role]
  end

  def set_remoteurl(url)
    logger.debug "set remoteurl"

    urlexists = has_element? 'remoteurl'

    if url.nil?
      delete_element if urlexists
    else
      add_element 'remoteurl' unless urlexists
      remoteurl.text = url
    end
  end

  #removes persons based on attributes
  def remove_persons(opt={})
    xpath="//person"
    if not opt.empty?
      opt_arr = []
      opt.each {|k,v| opt_arr << "@#{k}='#{v}'" unless v.nil? or v.empty?}
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    each(xpath) {|e| delete_element e}
  end

  def remove_group(opt={})
    xpath="//group"
    if not opt.empty?
      opt_arr = []
      opt.each {|k,v| opt_arr << "@#{k}='#{v}'" unless v.nil? or v.empty?}
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing groups using xpath '#{xpath}'"
    each(xpath) {|e| delete_element e}
  end

  def add_path_to_repository(opt={})
    return nil if opt == {}
    repository = self.find_first("//repository[@name='#{opt[:reponame]}']")

    unless opt[:repo_path].blank?
      opt[:repo_path] =~ /(.*)\/(.*)/;
      repository.each_path do |path| # Check if the path to add is already existant
        return false if path.project == $1 and path.repository == $2
      end

      param = self.add_element('path', :project => $1, :repository => $2)
      # put it on top
      first = repository.each.first
      if first != param
	first.move_after(param)
      end
    end
  end

  def add_repository( opt={} )
    return nil if opt == {}
    repository = add_element 'repository', 'name' => opt[:reponame]

    unless opt[:repo_path].blank?
      opt[:repo_path] =~ /(.*)\/(.*)/;
      repository.add_element 'path', 'project' => $1, 'repository' => $2
    end

    opt[:arch].to_a.each do |arch_text,dummy|
      arch = repository.add_element 'arch'
      arch.text = arch_text
    end
  end

  def remove_path_from_target( repository, path_project, path_repository )
    return nil if not repository
    return nil if not path_project
    return nil if not path_repository

    path = self.find_first("//repository[@name='#{repository}']/path[@project='#{path_project}'][@repository='#{path_repository}']")
    delete_element path if path
  end

  def remove_repository( repository )
    return nil if not repository
    return nil if not self.has_element? :repository

    repository = self.find_first("//repository[@name='#{repository}']")
    delete_element repository if repository
  end


  def add_maintained_project(maintained_project)
    return nil if not maintained_project
    add_element('maintenance') if not has_element?('maintenance')
    maintenance.add_element('maintains', 'project' => maintained_project)
  end

  def remove_maintained_project(maintained_project)
    return nil if not maintained_project
    return nil if not has_element?('maintenance')
    maintenance.delete_element("maintains[@project='#{maintained_project}']")
  end

  #get all architectures used in this project
  #TODO could/should be optimized... somehow...here are many possibilities
  #eg. object attribute, ...
  def architectures
    #saves 30 ms
    unless my_architectures.nil?
      return my_architectures
    end
    archs = Hash.new
    self.each('repository/arch') do |arch|
      archs[arch.to_s] = nil
    end
    #hash to array
    self.my_architectures = archs.keys.sort
    return self.my_architectures
  end

  def repositories
    ret = Array.new
    self.each_repository {|repo| ret << repo.name.to_s}
    ret
  end

  def repository
    repo_hash = Hash.new
    self.each_repository {|repo| repo_hash[repo.name] = repo}
    return repo_hash
  end
    
  def linking_projects
    result = []
    begin
      fc = FrontendCompat.new
      answer = fc.do_post(nil, {:project => self.name, :cmd => 'showlinked'})
      doc = ActiveXML::Base.new(answer)
      doc.each('/collection/project') {|e| result << e.value('name')}
    rescue ActiveXML::Transport::NotFoundError
      # No answer is ok, it only means no linking projects...
    end
    return result
  end

  def bugowners
    return users('bugowner')
  end

  def user_has_role?(user, role)
    user = Person.find_cached(user.to_s) if user.class == String
    if user
      return true if find_first("person[@role='#{role}' and @userid='#{user.login}']")
      each("group[@role='#{role}']") do |g|
        return true if user.is_in_group?(g.value(:groupid))
      end
    end
    return false
  end

  def group_has_role?(group, role)
    each("group") do |g|
      return true if g.value(:role) == role and g.value(:groupid) == group
    end
    return false
  end

  def users(role = nil)
    users = []
    each_person do |p|
      if not role or (role and p.role == role)
        users << p.userid
      end
      user = Person.find_cached(p.userid)
      if user
        each_group do |g|
          if not role or (role and g.role == role)
            users << p.userid if user.is_in_group?(g.groupid)
          end
        end
      end
    end
    return users.sort.uniq
  end

  def groups(role = nil)
    groups = []
    each_group do |g|
      if not role or (role and g.role == role)
        groups << g.groupid
      end
    end
    return groups.sort.uniq
  end

  def is_maintainer?(user)
    return user_has_role?(user, 'maintainer')
  end

  def can_edit?(user)
    user = Person.find_cached(user.to_s) if user.class == String or user.class == ActiveXML::LibXMLNode
    return false if not user
    return true if user.is_admin?
    return is_maintainer?(user)
  end

  def name
    @name ||= value('name')
  end

  def project_type
    return value('kind')
  end

  def set_project_type(project_type)
    if ['maintenance', 'maintenance_incident', 'standard'].include?(project_type)
      set_attribute('kind', project_type)
      return true
    end
    return false
  end

  def is_remote?
    has_element? "remoteurl"
  end

  # Returns a list of pairs (full name, short name) for each parent

  def self.parent_projects(project_name)
    return Rails.cache.fetch("parent_projects_#{project_name}", :expires_in => 7.days) do
      atoms = project_name.split(':')
      projects = []
      unused = 0

      for i in 1..atoms.length do
        p = atoms.slice(0, i).join(":")
        r = atoms.slice(unused, i - unused).join(":")
        if Project.exists? p
          projects << [p, r]
          unused = i
        end
      end
      projects
    end
  end

  def parent_projects
    return Project.parent_projects(self.name)
  end

  # Searches the maintenance project for a given project
  def self.maintenance_project(project_name)
    predicate = "maintenance/maintains/@project='#{project_name}'"
    mp = Collection.find_cached(:id, :what => 'project', :predicate => predicate, :expires_in => 30.minutes)
    return mp.each.first.name if mp.has_elements?
    return nil
  end

  def maintenance_project
    return Project.maintenance_project(self.name)
  end

  def self.attributes(project_name)
    path = "/source/#{project_name}/_attribute/"
    res = ActiveXML::Config::transport_for(:project).direct_http(URI("#{path}"))
    return Collection.new(res)
  end

  def attributes
    return Project.attributes(self.name)
  end

  def self.has_attribute?(project_name, attribute_namespace, attribute_name)
    self.attributes(project_name).each do |attr|
      return true if attr.namespace == attribute_namespace && attr.name == attribute_name
    end
    return false
  end

  def has_attribute?(attribute_namespace, attribute_name)
    return Project.has_attribute?(self.name, attribute_namespace, attribute_name)
  end

  # Returns maintenance incidents by type for current project (if any)
  def maintenance_incidents(type = 'open')
    predicate = "starts-with(@name,'#{self.name}:') and @kind='maintenance_incident'"
    case type
      when 'open' then predicate += " and repository/releasetarget/@trigger='maintenance'"
      when 'closed' then predicate += " and not(repository/releasetarget/@trigger='maintenance')"
    end
    return Collection.find_cached(:what => 'project', :predicate => predicate).each
  end

  def patchinfo
    begin
      return Patchinfo.find_cached(:project => self.name, :package => 'patchinfo')
    rescue ActiveXML::Transport::Error, ActiveXML::ParseError => e
      return nil
    end
  end

  def packages
    pkgs = Package.find_cached(:project => self.name)
    if pkgs
      return pkgs.each
    else
      return []
    end
  end

  def issues
    issues = Project.find_cached(:issues, :name => self.name)
    if issues
      changes_issues = {}
      patchinfo_issues = {}
      issues.each(:package) do |package|
        package.each(:issue) do |issue|
          if package.value('name') == 'patchinfo'
            patchinfo_issues[issue.value('long_name')] = issue
          else
            changes_issues[issue.value('long_name')] = issue
          end
        end
      end
     #open_issues, closed_issues = 0, 0
     #changes_issues.each do |name, issue|
     #  open_issues += 1 if issue.value('state') == 'OPEN'
     #  closed_issues += 1 if issue.value('state') == 'CLOSED'
     #end
      return changes_issues, patchinfo_issues
    else
      return {}, {}
    end
  end

end
