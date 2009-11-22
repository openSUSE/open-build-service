class Project < ActiveXML::Base
  include FlagModelHelper 
  
  has_many :package
  has_many :repository

  attr_accessor :build_flags
  attr_accessor :publish_flags
  attr_accessor :debuginfo_flags
  attr_accessor :useforbuild_flags

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
    xml_attr_accessor 'name'

    def archs
      @archs ||= each_arch.map { |a| a.to_s }
      return @archs
    end

    def add_arch (arch)
      return nil if archs.include? arch
      @archs.push arch
      e = data.add_element('arch')
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
    begin
      Project.find pro_name
      return true
    rescue ActiveXML::Transport::NotFoundError
      return false
    end
  end

  #TODO untested!!!!
  #TODO same function as in package
  def complex_flag_configuration? ( flagtype )

    unless self.has_element? flagtype.to_sym
      return false
    end

    flag_hash = Hash.new
    #iterates over the package.xml
    self.send(flagtype).each do |flag|
      arch = ( (flag.arch if flag.has_attribute? :arch) or 'all' )
      repo = ( (flag.repository if flag.has_attribute? :repository) or 'all' )
      #is now handled from the invalid repo check method
      #return true if flag_hash["#{repo}::#{arch}".to_sym] == true
      flag_hash.merge! "#{repo}::#{arch}".to_sym => true
    end
    return false
  end


  def set_buildflags(flags_as_hash)
    self.build_flags = flags_as_hash
  end


  def set_publishflags(flags_as_hash)
    self.publish_flags = flags_as_hash
  end

  
  def set_debuginfoflags(flags_as_hash)
    self.debuginfo_flags = flags_as_hash
  end


  def set_useforbuildflags(flags_as_hash)
    self.useforbuild_flags = flags_as_hash
  end


  def buildflags
    if self.bf_updated.nil? or self.build_flags.nil?
      self.bf_updated = true
      create_flag_matrix(:flagtype => 'build')
      update_flag_matrix(:flagtype => 'build')

    end

    return build_flags
  end


  def publishflags
    if self.pf_updated.nil? or self.publish_flags.nil?
      self.pf_updated = true
      create_flag_matrix(:flagtype => 'publish')
      update_flag_matrix(:flagtype => 'publish')

    end

    return publish_flags
  end
  
  
  def debuginfoflags
    if self.df_updated.nil? or self.debuginfo_flags.nil?
      self.df_updated = true
      create_flag_matrix(:flagtype => 'debuginfo')
      update_flag_matrix(:flagtype => 'debuginfo')

    end

    return debuginfo_flags
  end  


  def useforbuildflags
    if self.uf_updated.nil? or self.useforbuild_flags.nil?
      self.uf_updated = true
      create_flag_matrix(:flagtype => 'useforbuild')
      update_flag_matrix(:flagtype => 'useforbuild')

    end

    return useforbuild_flags
  end
  

  def to_s
    name.to_s
  end


  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to project #{self.name}"

    if( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    #add the new person
    data.add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]

    merge_data elem_cache
  end

  #removes persons based on attributes
  def remove_persons( opt={} )
    xpath="person"
    if not opt.empty?
      opt_arr = []
      opt.each do |k,v|
        opt_arr << "@#{k}='#{v}'"
      end
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.each_element(xpath) do |e|
      data.delete_element e
    end
  end

  def add_repository( opt={} )
    return nil if opt == {}
    repository = REXML::Element.new 'repository'
    repository.attributes['name'] = opt[:reponame]

    if opt[:platform]
      opt[:platform] =~ /(.*)\/(.*)/;
      repository.add_element 'path', 'project' => $1, 'repository' => $2
    end

    opt[:arch].to_a.each do |arch_text|
      arch = repository.add_element('arch')
      arch.text = arch_text
    end

    data.add_element repository
  end

  def remove_repository( repository )
    return nil if not repository
    return nil if not self.has_element? :repository

    data.delete_element "repository[@name='#{repository}']"
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
    self.repositories.each do |repo|
      repo.each_arch do |arch|
        archs[arch.to_s] = nil
      end
    end
    #hash to array
    self.my_architectures = archs.keys.sort
    return self.my_architectures
  end


  #get all repositories for this project
  #TODO could/should be optimized... somehow...there are many possibilities
  #eg. object attribute, ...
  def repositories
    #saves 50ms
    #self.my_repositories ||= self.each_repository
    #return self.my_repositories
    return invalid_repo_check(self,self)
  end


  def repository
    my_repo_hash ||= Hash[* repositories.map { |repo| [repo.name, repo] }.flatten ] # hacky way to make a hash from a map
    return my_repo_hash
  end
    

  #TODO use setter method!
  def create_flag_matrix( opts )
    begin
      flagtype = opts[:flagtype]
      logger.debug "[PROJECT-FLAGS] Creating flag matrix for flagtype: #{flagtype}"
      flags = Hash.new

      key = 'all::all'

      df = Flag.new
      df.id = key
      df.name = flagtype
      df.description = 'project default'
      df.architecture = nil
      df.repository = nil
      if opts[:flagtype] == "debuginfo"
        df.status = 'disable'
      else
        df.status = 'enable'
      end
      df.explicit = true

      flags.merge! key.to_sym => df

      #get repositories and architectures
      raise RuntimeError.new("[PROJECT-FLAGS] Warning: The Project #{self.name} has no " +
          "repository specified, therefore the creation of the flag-matrix is not possible.") \
        if self.repositories.empty?

      self.repositories.each do |repo|
        #generate repo::all flags and set the default
        key = repo.name.to_s + '::all'

        rdf = Flag.new
        rdf.id = key
        rdf.name = flagtype
        rdf.description = 'project repository default'
        rdf.architecture = nil
        rdf.repository = repo.name
        rdf.status = 'default'
        rdf.explicit = false
        rdf.set_implicit_setters( flags['all::all'.to_sym] )

        flags.merge! key.to_sym => rdf

        #set defaults for each architecture
        repo.each_arch do |arch|
          unless flags.keys.include? "all::#{arch.to_s}".to_sym
            key = 'all::' + arch.to_s

            adf = Flag.new
            adf.id = key
            adf.name = flagtype
            adf.description = 'project architecture default'
            adf.architecture = arch.to_s
            adf.repository = nil
            adf.status = 'default'
            adf.explicit = false
            adf.set_implicit_setters( flags['all::all'.to_sym] )

            value = adf
            flags.merge! key.to_sym => value
          end #end unless

          unless flags.keys.include? "#{repo.name}::#{arch.to_s}".to_sym
            key = repo.name + '::' + arch.to_s

            adf = Flag.new
            adf.id = key
            adf.name = flagtype
            adf.description = 'project flag'
            adf.architecture = arch.to_s
            adf.repository = repo.name
            adf.status = 'default'
            adf.explicit = false

            firstflag = flags["#{repo.name}::all".to_sym]
            secondflag = flags["all::#{arch.to_s}".to_sym]
            adf.set_implicit_setters( firstflag, secondflag  )

            flags.merge! key.to_sym => adf
          end
        end
      end

      ft = "set_#{flagtype}flags"
      self.send ft , flags

      logger.debug "[PROJECT-FLAGS] Creation done."
    rescue RuntimeError => error
      logger.debug error.message
      raise
    rescue
      raise
    end
  end


  #TODO remove flags on repository remove
  def update_flag_matrix(opts)
    flagtype = opts[:flagtype]
    logger.debug "[PROJECT-FLAGS] Updating flag matrix for flagtype: #{flagtype}"

    return unless self.has_element? flagtype.to_sym

    self.send(flagtype).each do |elem|
      begin
        if elem.has_attribute? :repository and elem.has_attribute? :arch
          key = elem.repository.to_s + '::' + elem.arch.to_s
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = elem.repository
          f.architecture = elem.arch.to_s
          f.status = elem.element_name
          f.explicit = true
        elsif elem.has_attribute? :repository
          key  =  elem.repository.to_s + '::all'
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = elem.repository
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
        elsif elem.has_attribute? :arch
          key = 'all::' + elem.arch.to_s
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = nil
          f.architecture = elem.arch.to_s
          f.status = elem.element_name
          f.explicit = true
        else
          #dickes default
          key = 'all::all'
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = nil
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
        end
      rescue NoMethodError => error
        logger.debug "[PROJECT-FLAGS] flag-matrix update warning: for the " +
          "requested flag-repo-arch-combination exists no entry in the flag-matrix" +
          " ...ignored!"
      end
    end

    logger.debug "[PROJECT-FLAGS] Update done."
  end

  def bugowner
    if has_element? "person[@role='bugowner']"
      return person("@role='bugowner'").userid.to_s
    else
      return nil
    end
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

end
