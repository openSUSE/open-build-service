module FlagHelper
  class InvalidFlag < APIException
    setup 'invalid_flag'
  end

  TYPES = {
    'lock'           => :disable,
    'build'          => :enable,
    'publish'        => :enable,
    'debuginfo'      => :disable,
    'useforbuild'    => :enable,
    'binarydownload' => :enable,
    'sourceaccess'   => :enable,
    'access'         => :enable
  }
  def self.default_for(flag_type)
    TYPES[flag_type.to_s].to_s
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
      flags.delete_all
      position = 1
      FlagHelper.flag_types.each do |flagtype|
        position = update_flags( xmlhash, flagtype, position )
      end
    end
  end

  def update_flags( xmlhash, flagtype, position )
    # translate the flag types as used in the xml to model name + s
    validate_type flagtype

    # select each build flag from xml
    xmlhash.elements(flagtype.to_s) do |xmlflags|
      xmlflags.keys.each do |status|
        fs = xmlflags.elements(status)
        if fs.empty? # make sure we treat empty too
          fs << {}
        end
        fs.each do |xmlflag|
          # get the selected architecture from data base
          arch = xmlflag['arch']
          arch = Architecture.find_by_name!(arch) if arch

          repo = xmlflag['repository']

          # instantiate new flag object
          flags.new(status: status, position: position, flag: flagtype) do |flag|
            # set the flag attributes
            flag.repo = repo
            flag.architecture = arch
          end
          position += 1
        end
      end
    end

    position
  end

  def remove_flag(flag, repository, arch = nil)
    validate_type flag
    flaglist = flags.of_type(flag)
    arch = Architecture.find_by_name(arch) if arch

    flags_to_remove = Array.new
    flaglist.each do |f|
      next if !repository.blank? && f.repo != repository
      next if repository.blank? && !f.repo.blank?
      next if !arch.blank? && f.architecture != arch
      next if arch.blank? && !f.architecture.nil?
      flags_to_remove << f
    end
    flags.delete(flags_to_remove)
  end

  def add_flag(flag, status, repository = nil, arch = nil)
    validate_type flag
    unless status == 'enable' || status == 'disable'
      raise ArgumentError.new("Error: unknown status for flag '#{status}'")
    end
    flags.build( status: status, flag: flag ) do |f|
      f.architecture = Architecture.find_by_name(arch) if arch
      f.repo = repository
    end
  end

  def set_repository_by_product(flag, status, product_name, patchlevel = nil)
    validate_type flag

    prj = self
    prj = project if kind_of? Package
    update = nil

    # we find all repositories targeted by given products
    p={name: product_name}
    p[:patchlevel] = patchlevel if p
    Product.where(p).each do |product|
      # FIXME: limit to official ones

      product.product_update_repositories.each do |ur|
        prj.repositories.each do |repo|
          repo.release_targets.each do |rt|
            next unless rt.target_repository == ur.repository
            # MATCH!
            if status
              add_flag(flag, status, rt.repository.name)
            else
              remove_flag(flag, rt.repository.name)
            end
          end
        end
      end
    end

    store if update
  end

  def enabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "enabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state}"
    state.to_sym == :enable ? true : false
  end

  def disabled_for?(flag_type, repo, arch)
    state = find_flag_state(flag_type, repo, arch)
    logger.debug "disabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state}"
    state.to_sym == :disable ? true : false
  end

  def find_flag_state(flag_type, repo, arch)
    flag = flags.of_type(flag_type).
      select { |f| f.is_relevant_for?(repo, arch) }.
      sort_by(&:specifics).
      last

    state = flag.try(:status) || :default

    if state == :default
      if respond_to? 'project'
        logger.debug 'flagcheck: package has default state, checking project'
        state = project.find_flag_state(flag_type, repo, arch)
      else
        state = FlagHelper.default_for(flag_type)
      end
    end

    state
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
    disabled
  end
end
