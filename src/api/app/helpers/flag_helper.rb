module FlagHelper

   def update_all_flags(obj)
      %w(build publish debuginfo useforbuild binarydownload sourceaccess privacy access).each do |flagtype|
        update_flags( obj, flagtype )
      end
   end

  def update_flags( obj, flagtype )
    #needed opts: :flagtype
    flagclass = nil
    flag = nil

    #translate the flag types as used in the xml to model name + s
    if %w(build publish debuginfo useforbuild binarydownload sourceaccess privacy access).include? flagtype.to_s
      flags = flagtype.to_s + "_flags"
    else
      raise  SaveError.new( "Error: unknown flag type '#{flagtype}' not found." )
    end

    if obj.has_element? flagtype.to_s

      #remove old flags
      Flag.transaction do
        self.send(flags).destroy_all

        #select each build flag from xml
        position = 0
        obj.send(flagtype).each do |xmlflag|

          #get the selected architecture from data base
          arch = nil
          if xmlflag.has_attribute? :arch
            arch = Architecture.find_by_name(xmlflag.arch)
            raise SaveError.new( "Error: Architecture type '#{xmlarch}' not found." ) if arch.nil?
          end

          repo = xmlflag.repository if xmlflag.has_attribute? :repository
          repo ||= nil

          #instantiate new flag object
          self.send(flags).create(:status => xmlflag.data.name, :position => position) do |flag|
            #set the flag attributes
            flag.repo = repo
            arch.send(flags) << flag unless arch.nil?
          end
          position += 1
        end
      end

    else
      logger.debug "[FLAGS] Seems that the users has deleted all flags of the type #{flags.singularize.camelize}, we will also do so!"
      self.send(flags).destroy_all
    end

    #self.reload
    return true
  end

  def remove_flag(flag, repository, arch)
    flagtype = nil
    #translates the flag types as used in the xml to model name + s
    if %w(build publish debuginfo useforbuild binarydownload sourceaccess privacy access).include? flag.to_s
      flagtype = flag.to_s + "_flags"
    else
      raise ArgumentError.new( "Error: unknown flag type '#{flag}' not found." )
    end
    flaglist = self.__send__(flagtype)
    arch = Architecture.find_by_name(arch) if arch

    flags_to_remove = Array.new
    flaglist.each do |f|
       next if !repository.blank? and f.repo != repository
       next if repository.blank? and !f.repo.blank?
       next if !arch.blank? and f.architecture != arch
       next if arch.blank? and !f.architecture.nil? 
       flags_to_remove << f
       f.destroy
    end
    self.__send__(flagtype).delete(flags_to_remove)
  end

  def add_flag(flag, status, repository, arch)
    flagtype = nil
    #translates the flag types as used in the xml to model name + s
    if %w(build publish debuginfo useforbuild binarydownload sourceaccess privacy access).include? flag.to_s
      flagtype = flag.to_s + "_flags"
    else
      raise ArgumentError.new( "Error: unknown flag type '#{flag}' not found." )
    end
    unless status == 'enable' or status == 'disable'
      raise ArgumentError.new("Error: unknown status for flag '#{status}'")
    end
    position = self.__send__(flagtype).maximum('position') || 0
    self.__send__(flagtype).create( :status => status, :position => position + 1 ) do |flag|
      flag.architecture = Architecture.find_by_name(arch) if arch
      flag.repo = repository
    end
  end

end
