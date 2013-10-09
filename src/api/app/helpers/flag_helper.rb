module FlagHelper

  class InvalidFlag < APIException
    setup 'invalid_flag'
  end

  def type_flags(type)
    ret = []
    flags.each do |f|
      ret << f if f.flag == type
    end
    return ret
  end

  TYPES = { 
    'lock' => :disable,
    'build' => :enable,
    'publish' => :enable,
    'debuginfo' => :disable,
    'useforbuild' => :enable,
    'binarydownload' => :enable,
    'sourceaccess' => :enable,
    'access' => :enable 
  }
  def self.default_for(flag_type)
    return TYPES[flag_type.to_s].to_s
  end
  
  def self.flag_types
    TYPES.keys
  end

  def validate_type( flag ) 
    unless TYPES.has_key? flag.to_s
      raise InvalidFlag.new( "Error: unknown flag type '#{flag}' not found." )
    end
  end

  def update_all_flags(xmlhash)
    Flag.transaction do
      self.flags.delete_all
      position = 1
      FlagHelper.flag_types.each do |flagtype|
        position = update_flags( xmlhash, flagtype, position )
      end
    end
  end

  def update_flags( xmlhash, flagtype, position )

    #translate the flag types as used in the xml to model name + s
    validate_type flagtype

    #select each build flag from xml
    xmlhash.elements(flagtype.to_s) do |xmlflags|
      xmlflags.keys.each do |status|
        fs = xmlflags.elements(status)
        if fs.empty? # make sure we treat empty too
          fs << {}
        end
        fs.each do |xmlflag|
          
          #get the selected architecture from data base
          arch = xmlflag['arch']
          arch = Architecture.find_by_name!(arch) if arch
          
          repo = xmlflag['repository']
            
          #instantiate new flag object
          self.flags.new(:status => status, :position => position, :flag => flagtype) do |flag|
            #set the flag attributes
            flag.repo = repo
            flag.architecture = arch
          end
          position += 1
        end
      end
    end
    
    return position
  end

  def remove_flag(flag, repository, arch)
    validate_type flag
    flaglist = self.type_flags(flag)
    arch = Architecture.find_by_name(arch) if arch

    flags_to_remove = Array.new
    flaglist.each do |f|
      next if !repository.blank? and f.repo != repository
      next if repository.blank? and !f.repo.blank?
      next if !arch.blank? and f.architecture != arch
      next if arch.blank? and !f.architecture.nil? 
      flags_to_remove << f
    end
    self.flags.delete(flags_to_remove)
  end

  def add_flag(flag, status, repository = nil, arch = nil)
    validate_type flag 
    unless status == 'enable' or status == 'disable'
      raise ArgumentError.new("Error: unknown status for flag '#{status}'")
    end
    self.flags.build( status: status, flag: flag ) do |f|
      f.architecture = Architecture.find_by_name(arch) if arch
      f.repo = repository
    end
  end

  def enabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "enabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state.to_s}"
    return state.to_sym == :enable ? true : false
  end

  def disabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "disabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state.to_s}"
    return state.to_sym == :disable ? true : false
  end

  def find_flag_state(flag_type, repo, arch)
    state = :default

    flags = Array.new
    self.type_flags(flag_type).each do |flag|
      flags << flag if flag.is_relevant_for?(repo, arch)
    end
    flags.sort! { |a,b| a.specifics <=> b.specifics }
    flags.each do |flag|
      state = flag.status
    end

    if state == :default
      if self.respond_to? 'project'
        logger.debug 'flagcheck: package has default state, checking project'
        state = self.project.find_flag_state(flag_type, repo, arch)
      else
        state = FlagHelper.default_for(flag_type)
      end
    end

    return state
  end

  def flags_to_xml(builder, expand_flags, pkg=nil)
    FlagHelper.flag_types.each do |flag_name|
      next if pkg and flag_name == 'access' # no access flag in packages
      builder.send(flag_name) do
        expand_flags[flag_name].each do |l|
          builder.send(l[0], l[1])
        end
      end
    end
  end

  def self.xml_disabled_for?(xmlhash, flagtype)
    Rails.logger.debug "xml_disabled? #{xmlhash.inspect}"
    disabled = false
    xmlhash.elements(flagtype.to_s) do |xmlflags|
      xmlflags.keys.each do |status|
        disabled = true if status == 'disable'
        return false if status == 'enable'
      end
    end
    return disabled
  end
  
end
