class Project < ActiveXML::Base
  include FlagModelHelper
  
  has_many :package

  attr_accessor :build_flags
  attr_accessor :publish_flags
  attr_accessor :debug_flags
  attr_accessor :useforbuild_flags

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  #cache variables
  attr_accessor :my_repositories
  attr_accessor :my_architectures

  handles_xml_element 'project'

  #check if named project exists
  def self.exists?(pro_name)
    begin
      Project.find pro_name
      return true
    rescue ActiveXML::NotFoundError
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
      return true if flag_hash["#{repo}::#{arch}".to_sym] == true
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

  
  def set_debugflags(flags_as_hash)
    self.debug_flags = flags_as_hash
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
  
  
  def debugflags
    if self.df_updated.nil? or self.debug_flags.nil?
      self.df_updated = true
      create_flag_matrix(:flagtype => 'debug')
      update_flag_matrix(:flagtype => 'debug')

    end

    return debug_flags
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


  def add_package( package )


    return true


    logger.debug "adding package #{package} to project #{self}"

    if( has_element? :package )
      elem_cache = split_data_after :package
    elsif( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    #add the new package
    data.add_element 'package', 'name' => package.to_s, 'revision' => 1

    #readd the removed elements
    merge_data elem_cache
  end

  def remove_package( package )

    return true

    return nil unless package

    data.delete_element "package[@name='#{package}']"

    logger.debug "removing package '#{package}' from project #{self}"
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
    self.my_repositories ||= self.each_repository
    return self.my_repositories
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
        df.name = "#{flagtype}"
        df.description = 'project default'
        df.architecture = nil
        df.repository = nil
        df.status = 'enable'
        df.explicit = true

        value = df

        flags.merge! key.to_sym => value

        #get repositories and architectures
        raise RuntimeError.new("[PROJECT-FLAGS] Warning: The Project #{self.name} has no " +
          "repository specified, therefore the creation of the flag-matrix is not possible.") \
          if self.repositories.empty?
        self.repositories.each do |repo|
          #generate repo::all flags and set the default
          key = repo.name.to_s + '::all'

          rdf = Flag.new
          rdf.id = key
          rdf.name = "#{flagtype}"
          rdf.description = 'project repository default'
          rdf.architecture = nil
          rdf.repository = repo.name
          rdf.status = 'default'
          rdf.explicit = false
          #rdf.set_implicit_setters( self.send("#{flagtype}flags")['all::all'.to_sym] )
          rdf.set_implicit_setters( flags['all::all'.to_sym] )

          value = rdf
          #self.send("#{flagtype}_flags").merge! key.to_sym => value
          flags.merge! key.to_sym => value

          #set defaults for each architecture
          repo.each_arch do |arch|
            #unless self.send("#{flagtype}flags").keys.include? "all::#{arch.to_s}".to_sym
            unless flags.keys.include? "all::#{arch.to_s}".to_sym
              key = 'all::' + arch.to_s

              adf = Flag.new
              adf.id = key
              adf.name = "#{flagtype}"
              adf.description = 'project architecture default'
              adf.architecture = arch.to_s
              adf.repository = nil
              adf.status = 'default'
              adf.explicit = false
              #adf.set_implicit_setters( self.send("#{flagtype}flags")['all::all'.to_sym] )
              adf.set_implicit_setters( flags['all::all'.to_sym] )

              value = adf
              flags.merge! key.to_sym => value
            end #end unless

            unless flags.keys.include? "#{repo.name}::#{arch.to_s}".to_sym
              key = repo.name + '::' + arch.to_s

              adf = Flag.new
              adf.id = key
              adf.name = "#{flagtype}"
              adf.description = 'project flag'
              adf.architecture = arch.to_s
              adf.repository = repo.name
              adf.status = 'default'
              adf.explicit = false

              firstflag = flags["#{repo.name}::all".to_sym]
              secondflag = flags["all::#{arch.to_s}".to_sym]
              adf.set_implicit_setters( firstflag, secondflag  )


              value = adf
              flags.merge! key.to_sym => value
            end
          end
        end

      ft = "set_"+"#{flagtype}"+"flags"
      self.send ft.to_sym , flags

      logger.debug "[PROJECT-FLAGS] Creation done."
    rescue RuntimeError => error
      logger.debug error.message
      raise
    rescue
      raise
    end
  end


  #TODO beim repository loeschen muessen auch die flags aktualisiert werden!!!
  def update_flag_matrix(opts)
    flagtype = opts[:flagtype]
    logger.debug "[PROJECT-FLAGS] Updating flag matrix for flagtype: #{flagtype}"

    return unless self.has_element? flagtype.to_sym

    self.send(flagtype).each do |elem|
      begin
        key = nil
        value = nil
        if elem.has_attribute? :repository and elem.has_attribute? :arch
          key = elem.repository.to_s + '::' + elem.arch.to_s
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = elem.repository
          f.architecture = elem.arch.to_s
          f.status = elem.element_name
          f.explicit = true
          value = f
        elsif elem.has_attribute? :repository
          key  =  elem.repository.to_s + '::all'
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = elem.repository
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
          value =  f
        elsif elem.has_attribute? :arch
          key = 'all::' + elem.arch.to_s
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = nil
          f.architecture = elem.arch.to_s
          f.status = elem.element_name
          f.explicit = true
          value =  f
        else
          #dickes default
          key = 'all::all'
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.repository = nil
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
          value =  f
        end
      rescue NoMethodError => error
        logger.debug "[PROJECT-FLAGS] flag-matrix update warning: for the " +
          "requested flag-repo-arch-combination exists no entry in the flag-matrix" +
          " ...ignored!"
      end
    end

    logger.debug "[PROJECT-FLAGS] Update done."
  end
  
  private

end
