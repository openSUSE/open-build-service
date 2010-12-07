module FlagHelper

   class SaveError < Exception; end

   def type_flags(type)
     # do some performance tests to verify if the danger of caching this is worth it
     # more than a dozen flags in a object are very unlikely
     @next_position = 1
     ret = []
     self.flags.each do |f|
       ret << f if f.flag == type
       @next_position = f.position + 1
     end
     return ret
   end

   TYPES = { 
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
        raise ArgumentError.new( "Error: unknown flag type '#{flag}' not found." )
     end
   end

   def update_all_flags(obj)
      FlagHelper.flag_types.each do |flagtype|
        update_flags( obj, flagtype )
      end
   end

   def update_flags( obj, flagtype )

     #translate the flag types as used in the xml to model name + s
     validate_type flagtype
     Flag.transaction do

       #remove old flags       
       self.type_flags(flagtype).each do |f|
	 self.flags.delete(f)
       end

       if obj.has_element? flagtype.to_s
	 
	 #select each build flag from xml
	 position = @next_position
	 obj.send(flagtype).each do |xmlflag|

	   #get the selected architecture from data base
	   arch = nil
	   if xmlflag.has_attribute? :arch
	     arch = Architecture.find_by_name(xmlflag.arch)
	     raise SaveError.new( "Error: Architecture type '#{xmlflag.arch}' not found." ) if arch.nil?
	   end

	   repo = xmlflag.repository if xmlflag.has_attribute? :repository
	   repo ||= nil

	   #instantiate new flag object
	   self.flags.create(:status => xmlflag.data.name, :position => position, :flag => flagtype) do |flag|
	     #set the flag attributes
	     flag.repo = repo
	     flag.architecture = arch
	   end
	   position += 1
	 end
       end

    end

     return true
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

  def add_flag(flag, status, repository, arch)
    validate_type flag 
    unless status == 'enable' or status == 'disable'
      raise ArgumentError.new("Error: unknown status for flag '#{status}'")
    end
    self.flags.create( :status => status, :flag => flag ) do |flag|
      flag.architecture = Architecture.find_by_name(arch) if arch
      flag.repo = repository
    end
  end

  def enabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "enabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state.to_s}"
    return state == 'enable' ? true : false
  end

  def disabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "disabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state.to_s}"
    return state == 'disable' ? true : false
  end

  def find_flag_state(flag_type, repo, arch)
    state = :default

    self.type_flags(flag_type).each do |flag|
      state = flag.status if flag.is_relevant_for?(repo, arch)
    end

    if state == :default
      if self.respond_to? 'db_project'
        logger.debug "flagcheck: package has default state, checking project"
        state = self.db_project.find_flag_state(flag_type, repo, arch)
      else
        state = FlagHelper.default_for(flag_type)
      end
    end

    return state
  end
end
