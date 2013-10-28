require 'frontend_compat'

class WebuiProject < Webui::Node
  
  default_find_parameter :name

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  #cache variables
  attr_accessor :my_repositories, :my_repo_hash
  attr_accessor :my_architectures

  handles_xml_element 'project'

  def self.make_stub(opt)
    doc = ActiveXML::Node.new('<project/>')
    doc.set_attribute('name', opt[:name])
    doc.add_element 'title'
    doc.add_element 'description'
    doc
  end

  #check if named project exists
  def self.exists?(pro_name)
    Project.where(name: pro_name).exists?
  end

  attr_writer :api_obj
  def api_obj
    @api_obj ||= Project.find_by_name(to_s)
  end

  #check if named project comes from a remote OBS instance
  def self.is_remote?(pro_name)
    p = WebuiProject.find pro_name
    p && p.is_remote?
  end
  
  def to_s
    name
  end

  def to_param
    name
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

  def release_repository( repository, target=nil )
    # target is optional and may come as string "project/targetrepository"

    arguments = {:project => self.name, :cmd => 'release'}
    if target
      a=target.split(/\//)
      arguments[:targetproject] = a[0]
      arguments[:targetrepository] = a[1]
    end

    begin
      fc = FrontendCompat.new
      answer = fc.do_post(nil, arguments)
      doc = ActiveXML::Node.new(answer)
      doc.each('/collection/project') {|e| result << e.value('name')}
    rescue ActiveXML::Transport::NotFoundError
      # No answer is ok, it only means no linking projects...
    end
    return result
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
  def architectures
    self.my_architectures ||= api_obj.repositories.joins(:architectures).pluck('distinct architectures.name')
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
    user && api_obj.relationships.where(user: user, role_id: Role.rolecache[role]).exists?
  end

  def group_has_role?(group, role)
    each('group') do |g|
      return true if g.value(:role) == role and g.value(:groupid) == group
    end
    return false
  end

  def users(role = nil)
    rels = api_obj.relationships
    rels = rels.where(role: Role.rolecache[role]) if role
    users = rels.users.pluck(:user_id)
    rels.groups.each do |g|
      users << g.groups_users.pluck(:user_id)
    end
    User.where(id: users.flatten.uniq)
  end

  def groups(role = nil)
    rels = api_obj.relationships
    rels = rels.where(role: Role.rolecache[role]) if role
    Group.where(id: rels.groups.pluck(:group_id).uniq)
  end

  def name
    @name ||= to_hash['name']
  end

  def name=(s)
    @name = s
  end

  def to_param
    name
  end

  def project_type
    api_obj.project_type
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
    th.has_key?('remoteurl') || th.has_key?('mountproject')
  end

  def self.attributes(project_name)
    path = "/source/#{project_name}/_attribute/"
    res = ActiveXML::api.direct_http(URI("#{path}"))
    return Collection.new(res)
  end

  def attributes
    return WebuiProject.attributes(self.name)
  end

  def self.has_attribute?(project_name, attribute_namespace, attribute_name)
    self.attributes(project_name).each do |attr|
      return true if attr.namespace == attribute_namespace && attr.name == attribute_name
    end
    return false
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
    result = ActiveXML::api.direct_http(URI(path))
    return Collection.new(result).each
  end

  def patchinfo
    begin
      return WebuiPatchinfo.find(:project => self.name, :package => 'patchinfo')
    rescue ActiveXML::Transport::Error, ActiveXML::ParseError
      return nil
    end
  end

  def packages
    raise "needed?"
    pkgs = Webui::Package.find(:all, :project => self.name)
    if pkgs
      return pkgs.each
    else
      return []
    end
  end

  def issues
    return Rails.cache.fetch("changes_and_patchinfo_issues_#{self.name}2", :expires_in => 5.minutes) do
      issues = WebuiProject.find(:issues, :name => self.name, :expires_in => 5.minutes)
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
    api_obj.packages.pluck(:name).each do |pname|
      pkg_name, rt_name = pname.split('.', 2)
      pkg = Webui::Package.find(pname, :project => self.name)
      if pkg && rt_name
        if pkg_name == 'patchinfo'
          # Holy crap, we found a patchinfo that is specific to (at least) one release target!
          pi = WebuiPatchinfo.find(:project => self.name, :package => pkg_name)
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

  def is_locked?
    api_obj.is_locked?
  end

  def requests(opts)
    # called for the incidents requests
    opts = {:project => self.name}.merge opts
    ids = Webui::BsRequest.list_ids(opts)
    return Webui::BsRequest.ids(ids)
  end

  def buildresults(view = 'summary')
    return Buildresult.find(:project => self.name, :view => view)
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

  def self.find(name, opts = {})
    name = name.to_param
    begin
      ap = Project.get_by_name(name)
    rescue Project::UnknownObjectError
      return nil
    end
    if ap.kind_of? Project
      p = WebuiProject.new '<project/>'
      p.api_obj = ap
      p.name = ap.name
      p.instance_variable_set('@init_options', name: name)
    else
      p = super
    end
    p
  end

  def parse(data)
    if @api_obj
      data = @api_obj.to_axml
    end
    super(data)
  end
end
