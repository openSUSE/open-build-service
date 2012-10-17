require 'frontend_compat'

class Project < ActiveXML::Node
  
  default_find_parameter :name

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  #cache variables
  attr_accessor :my_repositories, :my_repo_hash
  attr_accessor :my_architectures

  handles_xml_element 'project'

  class Repository < ActiveXML::Node
    handles_xml_element 'repository'

    def archs
      @archs ||= to_hash.elements("arch")
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
      @paths ||= to_hash.elements("path").map {|p| "#{p["project"]}/#{p["repository"]}" }
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
    return true if p && p.is_remote?
    return false
  end
  
  def to_s
    to_hash["name"]
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
    return result if is_remote?
    begin
      fc = FrontendCompat.new
      answer = fc.do_post(nil, {:project => self.name, :cmd => 'showlinked'})
      doc = ActiveXML::Node.new(answer)
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
    login = user.to_hash["login"]
    if user && login
      to_hash.elements("person") do |p|
        return true if p["role"] == role && p["userid"] == login
      end
      to_hash.elements("group") do |g|
        return true if g["role"] == role && user.is_in_group?(g["groupid"])
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
    to_hash.elements("person") do |p|
      if not role or (role and p["role"] == role)
        users << p["userid"]
      end
      user = Person.find_cached(p["userid"])
      if user
        to_hash.elements("group") do |g|
          if not role or (role and g["role"] == role)
            users << p["userid"] if user.is_in_group?(g["groupid"])
          end
        end
      end
    end
    return users.uniq.sort
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
    return false if not user
    if user.class == String or user.class == ActiveXML::Node
      user = Person.find_cached(user.to_s)
      return false if not user
    end
    return true if user.is_admin?
    return is_maintainer?(user)
  end

  def name
    @name ||= to_hash["name"]
  end

  def project_type
    return to_hash["kind"]
  end

  def set_project_type(project_type)
    if ['maintenance', 'maintenance_incident', 'standard'].include?(project_type)
      set_attribute('kind', project_type)
      return true
    end
    return false
  end

  def is_remote?
    th = to_hash
    th.has_key?("remoteurl") || th.has_key?("mountproject")
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

  def self.attributes(project_name)
    path = "/source/#{project_name}/_attribute/"
    res = ActiveXML::transport.direct_http(URI("#{path}"))
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
  def maintenance_incidents(type = 'open', opts = {})
    predicate = "starts-with(@name,'#{self.name}:') and @kind='maintenance_incident'"
    case type
      when 'open' then predicate += " and repository/releasetarget/@trigger='maintenance'"
      when 'closed' then predicate += " and not(repository/releasetarget/@trigger='maintenance')"
    end
    path = "/search/project/?match=#{CGI.escape(predicate)}"
    path += "&limit=#{opts[:limit]}" if opts[:limit]
    path += "&offset=#{opts[:offset]}" if opts[:offset]
    result = ActiveXML::transport.direct_http(URI(path))
    return Collection.new(result).each
  end

  def patchinfo
    begin
      return Patchinfo.find_cached(:project => self.name, :package => 'patchinfo')
    rescue ActiveXML::Transport::Error, ActiveXML::ParseError
      return nil
    end
  end

  def packages
    pkgs = Package.find(:all, :project => self.name)
    if pkgs
      return pkgs.each
    else
      return []
    end
  end

  def issues
    return Rails.cache.fetch("changes_and_patchinfo_issues_#{self.name}2", :expires_in => 5.minutes) do
      issues = Project.find_cached(:issues, :name => self.name, :expires_in => 5.minutes)
      if issues
        changes_issues, patchinfo_issues = {}, {}
        issues.each(:package) do |package|
          package.each(:issue) do |issue|
            if package.value('name') == 'patchinfo'
              patchinfo_issues[issue.value('label')] = issue
            else
              changes_issues[issue.value('label')] = issue
            end
          end
        end
        missing_issues, optional_issues = {}, {}
        changes_issues.each do |label, issue|
          optional_issues[label] = issue unless patchinfo_issues.has_key?(label)
        end
        patchinfo_issues.each do |label, issue|
          missing_issues[label] = issue unless changes_issues.has_key?(label)
        end
        {:changes => changes_issues, :patchinfo => patchinfo_issues, :missing => missing_issues, :optional => optional_issues}
      else
        {}
      end
    end
  end

  def release_targets_ng
    return Rails.cache.fetch("incident_release_targets_ng_#{self.name}2", :expires_in => 5.minutes) do
      # First things first, get release targets as defined by the project, err.. incident. Later on we
      # magically find out which of the contained packages, err. updates are build against those release
      # targets.
      release_targets_ng = {}
      self.each(:repository) do |repo|
        if repo.has_element?(:releasetarget)
          release_targets_ng[repo.releasetarget.value('project')] = {:reponame => repo.value('name'), :packages => [], :patchinfo => nil, :package_issues => {}, :package_issues_by_tracker => {}}
        end
      end

      # One catch, currently there's only one patchinfo per incident, but things keep changing every
      # other day, so it never hurts to have a look into the future:
      global_patchinfo = nil
      self.packages.each do |package|
        pkg_name, rt_name = package.value('name').split('.', 2)
        pkg = Package.find_cached(package.value('name'), :project => self.name)
        if pkg && rt_name
          if pkg_name == 'patchinfo'
            # Holy crap, we found a patchinfo that is specific to (at least) one release target!
            pi = Patchinfo.find_cached(:project => self.name, :package => pkg_name)
            begin
              release_targets_ng[rt_name][:patchinfo] = pi
            rescue 
              #TODO FIXME ARGH: API/backend need some work to support this better.
              # Until then, multiple patchinfos are problematic
            end
          else
            # Here we try hard to find the release target our current package is build for:
            found = false
            if pkg.has_element?(:build)
              # Stone cold map'o'rama of package.$SOMETHING with package/build/enable/@repository=$ANOTHERTHING to
              # project/repository/releasetarget/@project=$YETSOMETINGDIFFERENT. Piece o' cake, eh?
              pkg.build.each(:enable) do |enable|
                if enable.has_attribute?(:repository)
                  release_targets_ng.each do |rt_key, rt_value|
                    if rt_value[:reponame] == enable.value('repository')
                      rt_name = rt_key # Save for re-use
                      found = true
                      break
                    end
                  end
                end
                if !found
                  # Package only contains sth. like: <build><enable repository="standard"/></build>
                  # Thus we asume it belongs to the _only_ release target:
                  rt_name = release_targets_ng.keys.first
                end
              end
            else
              # Last chance, package building is disabled, maybe it's name aligns to the release target..
              release_targets_ng.each do |rt_key, rt_value|
                if rt_value[:reponame] == rt_name
                  rt_name = rt_key # Save for re-use
                  found = true
                  break
                end
              end
            end

            # Build-disabled packages can't be matched to release targets....
            if found
              # Let's silently hope that an incident newer introduces new (sub-)packages....
              release_targets_ng[rt_name][:packages] << pkg
              linkdiff = pkg.linkdiff()
              if linkdiff && linkdiff.has_element?('issues')
                linkdiff.issues.each(:issue) do |issue|
                  release_targets_ng[rt_name][:package_issues][issue.value('label')] = issue

                  release_targets_ng[rt_name][:package_issues_by_tracker][issue.value('tracker')] ||= []
                  release_targets_ng[rt_name][:package_issues_by_tracker][issue.value('tracker')] << issue
                end
              end
            end
          end
        elsif pkg_name == 'patchinfo'
          # Global 'patchinfo' without specific release target:
          global_patchinfo = self.patchinfo()
        end
      end

      if global_patchinfo
        release_targets_ng.each do |rt_name, rt|
          rt[:patchinfo] = global_patchinfo
        end
      end
      return release_targets_ng
    end
  end

  def is_locked?
    return has_element?('lock') && lock.has_element?('enable')
  end

  def requests(opts)
    opts = {:project => self.name}.merge opts
    return Rails.cache.fetch("project_requests_#{self.name}_#{opts}", :expires_in => 5.minutes) do
      BsRequest.list(opts)
    end
  end

  def buildresults(view = 'summary')
    return Buildresult.find_cached(:project => self.name, :view => view)
  end

  def build_succeeded?(repository = nil)
    states = {}
    repository_states = {}

    buildresults().each('result') do |result|

      if repository && result.repository == repository
        repository_states[repository] ||= {}
        result.each('summary') do |summary|
          summary.each('statuscount') do |statuscount|
            repository_states[repository][statuscount.value('code')] ||= 0
            repository_states[repository][statuscount.value('code')] += statuscount.value('count').to_i()
          end
        end
      else
        result.each('summary') do |summary|
          summary.each('statuscount') do |statuscount|
            states[statuscount.value('code')] ||= 0
            states[statuscount.value('code')] += statuscount.value('count').to_i()
          end
        end
      end
    end
    if repository && repository_states.has_key?(repository)
      return false if repository_states[repository].empty? # No buildresult is bad
      repository_states[repository].each do |state, count|
        return false if ['broken', 'failed', 'unresolvable'].include?(state)
      end
    else
      return false unless states.empty? # No buildresult is bad
      states.each do |state, count|
        return false if ['broken', 'failed', 'unresolvable'].include?(state)
      end
    end
    return true
  end

end
