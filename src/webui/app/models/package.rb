class Package < ActiveXML::Base
  include FlagModelHelper 
  
  belongs_to :project

  handles_xml_element 'package'

  #cache variables
  attr_accessor :my_pro
  attr_accessor :my_architectures

  #flags
  attr_accessor :build_flags
  attr_accessor :publish_flags
  attr_accessor :debuginfo_flags
  attr_accessor :useforbuild_flags

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated


  def initialize(*args)
    super(*args)
    @bf_updated = false
    @pf_updated = false
    @df_updated = false
    @uf_updated = false
  end


  def my_project
    self.my_pro ||= Project.find(self.project)
    return self.my_pro
  end


  def complex_flag_configuration? ( flagtype )

    unless self.has_element? flagtype.to_sym
      return false
    end

    flag_hash = Hash.new
    #iterates over the package.xml and check for identically with different states 
    self.send(flagtype).each do |flag|
      arch = ( (flag.arch if flag.has_attribute? :arch) or 'all' )
      repo = ( (flag.repository if flag.has_attribute? :repository) or 'all' )
      return true if flag_hash["#{repo}::#{arch}".to_sym] == true
      flag_hash.merge! "#{repo}::#{arch}".to_sym => true
    end
    #Find package-flags for architectures and repositories not included in the 
    #project config. This check is done separately because we will add support
    #for these flags to the webclient later. (and than this check will be obsolete)
    self.send(flagtype).each do |flag|
      project_repos = Array.new
      self.my_project.repositories.each do |repo|
        project_repos << repo.name
      end
      if flag.has_attribute? :repository
        #is now handled from the invalid repo check method
        #return true if not project_repos.include? flag.repository
      end
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
    unless self.bf_updated == true or not self.build_flags.nil?
      self.bf_updated = true
      create_flag_matrix(:flagtype => 'build')
      update_flag_matrix(:flagtype => 'build')
    end

    return build_flags
  end

  #TODO: publish flags occur only in projects, use this for other flags ;)
  def publishflags
    unless self.pf_updated == true or not self.publish_flags.nil?
      self.pf_updated = true
      create_flag_matrix(:flagtype => 'publish')
      update_flag_matrix(:flagtype => 'publish')
    end

    return publish_flags
  end


  def debuginfoflags
    unless self.df_updated == true or not self.debuginfo_flags.nil?
      self.df_updated = true
      create_flag_matrix(:flagtype => 'debuginfo')
      update_flag_matrix(:flagtype => 'debuginfo')
    end

    return debuginfo_flags
  end

  
  def useforbuildflags
    unless self.uf_updated == true or not self.useforbuild_flags.nil?
      self.uf_updated = true
      create_flag_matrix(:flagtype => 'useforbuild')
      update_flag_matrix(:flagtype => 'useforbuild')
    end

    return useforbuild_flags
  end
    

  def to_s
    name.to_s
  end

  def save_file( opt = {} )
    file = opt[:file]

    logger.debug "storing file: #{file.inspect}"

    put_opt = Hash.new
    put_opt[:package] = self.name
    put_opt[:project] = @init_options[:project]
    put_opt[:filename] = opt[:filename]

    fc = FrontendCompat.new
    fc.put_file file.read, put_opt
    true
  end

  def remove_file( name )
    delete_opt = Hash.new
    delete_opt[:package] = self.name
    delete_opt[:project] = @init_options[:project]
    delete_opt[:filename] = name

    FrontendCompat.new.delete_file delete_opt

    true
  end

  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to package #{self.name}"

    elem_cache = get_elements_before :person

    #add the new person
    add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]

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
    data.find(xpath).each {|e| e.remove! }
  end


  # disable building of this package for the specified repo / arch / repo/arch-combination
  def disable_build( opt={} )
    logger.debug "disable building of package #{self.name} for #{opt[:repo]} #{opt[:arch]}"

    elem_cache = get_elements_before :disable

    if opt[:repo] and opt[:arch]
      if data.find("disable[@repository='#{opt[:repo]}' and @arch='#{opt[:arch]}']").empty?
        add_element 'disable', 'repository' => opt[:repo], 'arch' => opt[:arch]
      else return false
      end
    else
      if opt[:repo]
        if data.find("disable[@repository='#{opt[:repo]}' and not(@arch)]").empty?
          add_element 'disable', 'repository' => opt[:repo]
        else return false
        end
      elsif opt[:arch]
        if data.find("disable[@arch='#{opt[:arch]}' and not(@repository)]").empty?
          add_element 'disable', 'arch' => opt[:arch]
        else return false
        end
      else
        if data.find("//disable[count(@*) = 0]").empty?
          add_element 'disable'
        else return false
        end
      end
    end

    merge_data elem_cache
    begin
      save
    rescue
      return false
    end
  end


  def set_url( new_url )
    logger.debug "set url #{new_url} for package #{self.name} (project #{self.project})"
    if( has_element? :url )
      url.text = new_url
    else
      elem_cache = get_elements_before :url
      data.add_element 'url'
      merge_data elem_cache
      url.text = new_url
    end
    save
  end


  def remove_url
    logger.debug "remove url from package #{self.name} (project #{self.project})"

    data.find('//url').each { |e| e.remove! }
    save
  end


  #get all architectures used in the project
  #TODO could/should be optimized... somehow...here are many possibilities
  #eg. object attribute, ...
  def architectures
    return my_project.architectures
  end


  #get all repositories
  def repositories
    #repos = my_project.repositories
    return invalid_repo_check(my_project,self)
  end


  def create_flag_matrix( opts={} )
    begin
      flagtype = opts[:flagtype]
      logger.debug "[PACKAGE-FLAGS] Creating flag matrix for flagtype: #{flagtype}"
      
      flags = Hash.new

      key = 'all::all'

      df = Flag.new
      df.id = key
      df.name = "#{flagtype}"
      df.description = 'package default'
      df.architecture = nil
      df.repository = nil
      df.status = 'default'
      df.explicit = false
      df.set_implicit_setters( self.my_project.send("#{flagtype}flags")[key.to_sym] )

      value = df

      flags.merge! key.to_sym => value

      #get repositories and architectures
      raise RuntimeError.new("[PACKAGE-FLAGS] Warning: The Project #{self.project} has no " +
        "repository specified, therefore the creation of the flag-matrix on #{self.name} is not possible.") \
        if self.repositories.empty?

      self.repositories.each do |repo|
        #generate repo::all flags and set the default
        key = repo.name + '::all'

        rdf = Flag.new
        rdf.id = key
        rdf.name = "#{flagtype}"
        rdf.description = 'package repository default'
        rdf.architecture = nil
        rdf.repository = repo.name
        rdf.status = 'default'
        rdf.explicit = false
        rdf.set_implicit_setters( flags['all::all'.to_sym],  self.my_project.send("#{flagtype}flags")[key.to_sym] )

        value = rdf
        flags.merge! key.to_sym => value

        #set defaults for each architecture
        repo.each_arch do |arch|
          unless flags.keys.include? "all::#{arch.to_s}".to_sym
            key = 'all::' + arch.to_s

            adf = Flag.new
            adf.id = key
            adf.name = "#{flagtype}"
            adf.description = 'package architecture default'
            adf.architecture = arch.to_s
            adf.repository = nil
            adf.status = 'default'
            adf.explicit = false
            #adf.set_implicit_setters( self.send("#{flagtype}flags")['all::all'.to_sym] )
            adf.set_implicit_setters( flags['all::all'.to_sym], self.my_project.send("#{flagtype}flags")[key.to_sym] )

            value = adf
            flags.merge! key.to_sym => value
          end #end unless

          #set defaults for each other flags
          unless flags.keys.include? "#{repo}::#{arch}".to_sym
            key = repo.name.to_s + '::' + arch.to_s

            adf = Flag.new
            adf.id = key
            adf.name = "#{flagtype}"
            adf.description = 'package flag'
            adf.architecture = arch.to_s
            adf.repository = repo.name
            adf.status = 'default'
            adf.explicit = false

            firstflag = flags["#{repo.name}::all".to_sym]
            secondflag = flags["all::#{arch.to_s}".to_sym]

            thirdflag  = flags["all::all".to_sym]
            forthflag = self.my_project.send("#{flagtype}flags")[key.to_sym]

            adf.set_implicit_setters( firstflag, secondflag, thirdflag, forthflag )

            value = adf

            flags.merge! key.to_sym => value
          end
        end
      end


      ft = "set_"+"#{flagtype}"+"flags"
      self.send ft.to_sym , flags
      logger.debug "[PACKAGE-FLAGS] Creation done."
    rescue RuntimeError => error
      logger.debug error
      raise
    rescue
      raise
    end
  end


  #TODO beim repository loeschen muessen auch die flags aktualisiert werden!!!
  def update_flag_matrix(opts={})
    flagtype = opts[:flagtype]

    logger.debug "[PACKAGE-FLAGS] Updating flag matrix for flagtype: #{flagtype}"

    return unless self.has_element? flagtype.to_sym
    self.send(flagtype).each do |elem|
      begin
        key = nil
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
          f.description = 'package repository default'
          f.repository = elem.repository
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
        elsif elem.has_attribute? :arch
          key = 'all::' + elem.arch.to_s
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.description = 'package architecture default'
          f.repository = nil
          f.architecture = elem.arch.to_s
          f.status = elem.element_name
          f.explicit = true
        else
          #dickes default
          key = 'all::all'
          f = self.send("#{flagtype}flags")[key.to_sym]
          f.description = 'package default'
          f.repository = nil
          f.architecture = nil
          f.status = elem.element_name
          f.explicit = true
        end
      rescue NoMethodError => error
        logger.debug "[PACKAGE-FLAGS] flag-matrix update warning: for the " +
          "requested flag-repo-arch-combination exists no entry in the flag-matrix" +
          " ...ignored!"
      end
    end
    logger.debug "[PACKAGE-FLAGS] Update done."
  end

  def bugowner
    if has_element? "person[@role='bugowner']"
      return person("@role='bugowner'").userid.to_s
    else
      return nil
    end
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def self.exists? package_name, project_name
    begin
      Package.find( package_name, :project => project_name )
      return true
    rescue ActiveXML::Transport::NotFoundError
      return false
    end
  end

  private

  def get_elements_before( element )
    # this is a helper method for inserting elements at the right place in xml,
    # it's necessary because the order of elements is important.
    # wished order:
    element_order = [
      :title, :description, :person, :build, :publish, :useforbuild, :notify, :delete_notify,
      :url, :group, :license, :keyword, :file
    ]
    until element_order.pop == element or element_order.empty? do end
    elem_cache = []
    element_order.reverse!
    element_order.each do |e|
      if has_element? e
        elem_cache = split_data_after e
        break
      end
    end
    return elem_cache
  end
end

