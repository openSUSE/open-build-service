class Project < ActiveXML::Base
  
  default_find_parameter :name

  has_many :package
  has_many :repository
  
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

    #    def name= (name)
    #      data.attributes['name'] = name
    #    end

  end

  #check if named project exists
  def self.exists?(pro_name)
    if Project.find pro_name
      return true
    else
      return false
    end
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

  def set_remoteurl( url )
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
  def remove_persons( opt={} )
    xpath="//person"
    if not opt.empty?
      opt_arr = []
      opt.each do |k,v|
        opt_arr << "@#{k}='#{v}'"
      end
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.find(xpath.to_s).each do |e| 
        e.remove!
    end
  end

  def add_path_to_repository( opt={} )
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
      repo.each_arch do |arch|
        archs[arch.to_s] = nil
      end
    end
    #hash to array
    self.my_architectures = archs.keys.sort
    return self.my_architectures
  end


  def repositories
    ret = Array.new
    self.each_repository do |repo|
      ret << repo.name.to_s
    end
    ret
  end


  def repository
    repo_hash = Hash.new
    self.each_repository do |repo|
      repo_hash[repo.name] = repo
    end
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

  def bugowner
    b = all_persons("bugowner")
    return b.first if b
    return nil
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

  def person_count
    @person_count ||= each_person.length
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def name
    @name ||= data.attributes['name']
  end

  def is_remote?
    has_element? "remoteurl"
  end

end
