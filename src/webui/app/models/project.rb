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
      @archs ||= each_arch.map { |a| a.to_s }
      return @archs
    end

    def add_arch (arch)
      return nil if archs.include? arch
      @archs.push arch
      e = add_element('arch')
      e.text = arch
    end

    def remove_arch (arch)
      return nil unless archs.include? arch
      each_arch do |a|
        delete_element a if a.to_s == arch
      end
      @archs.delete arch
    end

    def set_archs (new_archs)
      new_archs.map!{ |a| a.to_s }
      archs.reject{ |a| new_archs.include? a }.each{ |arch| remove_arch arch }
      new_archs.reject{ |a| archs.include? a }.each{ |arch| add_arch arch }
    end
    def archs= (new_archs)
      set_archs new_archs
    end

    def paths
      @paths ||= each_path.map { |p| p.project + '/' + p.repository }
      return @paths
    end

    def add_path (path)
      return nil if paths.include? path
      project, repository = path.split("/")
      @paths.push path
      e = add_element('path')
      e.data.attributes['repository'] = repository
      e.data.attributes['project'] = project
    end

    def remove_path (path)
      return nil unless paths.include? path
      project, repository = path.split("/")
      each_path do |p|
        delete_element p if p.data.attributes['project'] == project and p.data.attributes['repository'] == repository
      end
      @paths.delete path
    end

    def set_paths (new_paths)
      paths.clone.each{ |path| remove_path path }
      new_paths.each{ |path| add_path path }
    end
    
    def paths= (new_paths)
      set_paths new_paths
    end

    # directions are :up and :down
    def move_path (path, direction=:up)
      return nil unless (path and not paths.empty?)
      new_paths = paths.clone
      for i in 0..new_paths.length
        if new_paths[i] == path           # found the path to move?
          if direction == :up and i != 0  # move up and is not the first?
            tmp = new_paths[i - 1]
            new_paths[i - 1] = new_paths[i]
            new_paths[i] = tmp
            break
          elsif direction == :down and i != new_paths.length - 1
            tmp = new_paths[i + 1]
            new_paths[i + 1] = new_paths[i]
            new_paths[i] = tmp
            break
          end
        end
      end
      set_paths new_paths
    end

    #    def name= (name)
    #      data.attributes['name'] = name
    #    end

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

    if( has_element? :remoteurl )
      elem_cache = split_data_after :remoteurl
    else
      elem_cache = split_data_after :description
    end

    #add the new person
    add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]
    merge_data elem_cache
  end

  def add_group(opt={})
    return false unless opt[:groupid] and opt[:role]
    logger.debug "adding group '#{opt[:groupid]}', role '#{opt[:role]}' to project #{self.name}"

    if has_element?(:remoteurl)
      elem_cache = split_data_after :remoteurl
    else
      elem_cache = split_data_after :description
    end

    # add the new group
    add_element 'group', 'groupid' => opt[:groupid], 'role' => opt[:role]
    merge_data elem_cache
  end

  def set_remoteurl(url)
    logger.debug "set remoteurl"

    delete_element 'remoteurl'
    elem_cache = split_data_after :description

    unless url.nil?
      add_element 'remoteurl'
      remoteurl.text = url
    end
    merge_data elem_cache
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
    data.find(xpath.to_s).each {|e| e.remove!}
  end

  def remove_group(opt={})
    xpath="//group"
    if not opt.empty?
      opt_arr = []
      opt.each {|k,v| opt_arr << "@#{k}='#{v}'" unless v.nil? or v.empty?}
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing groups using xpath '#{xpath}'"
    data.find(xpath.to_s).each {|e| e.remove!}
  end

  def add_path_to_repository(opt={})
    return nil if opt == {}
    repository = data.find("//repository[@name='#{opt[:reponame]}']").first

    unless opt[:repo_path].blank?
      opt[:repo_path] =~ /(.*)\/(.*)/;
      param = XML::Node.new 'path'
      param['project'] = $1
      param['repository'] = $2
      # put it on top
      if repository.children?
        repository.children.first.prev = param
      else
        repository << param
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

    delete_element "//repository[@name='#{repository}']/path[@project='#{path_project}'][@repository='#{path_repository}']"
  end

  def remove_repository( repository )
    return nil if not repository
    return nil if not self.has_element? :repository

    delete_element "repository[@name='#{repository}']"
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
    self.each_repository do |repo|
      repo.each_arch {|arch| archs[arch.to_s] = nil}
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
    opt = Hash.new
    opt[:project] = self.name
    opt[:cmd] = "showlinked"
    fc = FrontendCompat.new
    answer = fc.do_post nil, opt

    doc = XML::Parser.string(answer).parse
    result = []
    doc.find("/collection/project").each do |e|
      result.push( e.attributes["name"] )
    end

    return result
  end

  def bugowners
    b = all_persons("bugowner")
    return nil if b.empty?
    return b
  end

  def all_persons( role )
    ret = Array.new
    each_person do |p|
      if p.role == role
        ret << p.userid.to_s
      end
    end
    return ret
  end

  def all_groups( role )
    ret = Array.new
    each_group do |p|
      if p.role == role
        ret << p.groupid.to_s
      end
    end
    return ret
  end

  def user_has_role?(userid, role)
    each_person do |p|
      return true if p.role == role and p.userid == userid
    end
    return false
  end

  def group_has_role?(groupid, role)
    each_group do |g|
      return true if g.role == role and g.groupid == groupid
    end
    return false
  end

  def users
    users = []
    each_person {|p| users.push(p.userid)}
    return users.sort.uniq
  end

  def groups
    groups = []
    each_group {|g| groups.push(g.groupid)}
    return groups.sort.uniq
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def can_edit? userid
    return false unless userid
    return true if is_maintainer? userid
    return true if Person.find_cached(userid).is_admin?
    all_groups("maintainer").each do |grp|
      return true if Person.find_cached(userid).is_in_group?(grp)
    end
    return false
  end

  def name
    @name ||= data.attributes['name']
  end

  def is_remote?
    has_element? "remoteurl"
  end

  # Returns a list of pairs (full name, short name) for each parent
  def self.parent_projects(project_name)
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
    return projects
  end

  def parent_projects
    return Project.parent_projects(self.name)
  end

end
