module FlagHelper
  class InvalidFlag < APIError
    setup 'invalid_flag'
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
  }.freeze

  def self.default_for(flag_type)
    TYPES[flag_type.to_s].to_s
  end

  def self.flag_types
    TYPES.keys
  end

  def validate_type(flag)
    raise InvalidFlag, "Error: unknown flag type '#{flag}' not found." unless TYPES.key?(flag.to_s)
  end

  def update_all_flags(xmlhash)
    Flag.transaction do
      flags.delete_all
      position = 1
      FlagHelper.flag_types.each do |flagtype|
        position = update_flags(xmlhash, flagtype, position)
      end
    end
  end

  def update_flags(xmlhash, flagtype, position)
    # translate the flag types as used in the xml to model name + s
    validate_type flagtype

    # we need to catch duplicates - and prefer the last
    flags_to_create = {}

    # select each build flag from xml
    xmlhash.elements(flagtype.to_s) do |xmlflags|
      xmlflags.keys.each do |status|
        fs = xmlflags.elements(status)
        fs << {} if fs.empty? # make sure we treat empty too
        fs.each do |xmlflag|
          # get the selected architecture from data base
          arch = xmlflag['arch']
          arch = Architecture.find_by_name!(arch) if arch

          repo = xmlflag['repository']

          key = "#{repo}-#{arch}"
          # overwrite duplicates - but prefer disables
          next if flags_to_create[key] && flags_to_create[key][:status] == 'disable'

          flags_to_create[key] = { status: status, position: position, repo: repo, architecture: arch }
          position += 1
        end
      end
    end

    flags_to_create.values.each do |flag|
      flags.build(flag.merge(flag: flagtype))
    end
    position
  end

  def remove_flag(flag, repository, arch = nil)
    validate_type flag
    flaglist = flags.of_type(flag)
    arch = Architecture.find_by_name(arch) if arch

    flags_to_remove = []
    flaglist.each do |f|
      next if repository.present? && f.repo != repository
      next if repository.blank? && f.repo.present?
      next if arch.present? && f.architecture != arch
      next if arch.blank? && !f.architecture.nil?

      flags_to_remove << f
    end
    flags.delete(flags_to_remove)
  end

  def add_flag(flag, status, repository = nil, arch = nil)
    validate_type flag
    raise ArgumentError, "Error: unknown status for flag '#{status}'" unless %w[enable disable].include?(status)

    flags.build(status: status, flag: flag) do |f|
      f.architecture = Architecture.find_by_name(arch) if arch
      f.repo = repository
    end
  end

  def set_repository_by_product(flag, status, product_name, patchlevel = nil)
    validate_type flag

    prj = self
    prj = project if is_a?(Package)
    update = nil

    # we find all repositories targeted by given products
    p = { name: product_name }
    p[:patchlevel] = patchlevel if p
    Product.where(p).find_each do |product|
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
    state = find_flag_status(flag_type, repo, arch)
    logger.debug "enabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state}"
    state.to_sym == :enable
  end

  def disabled_for?(flag_type, repo, arch)
    state = find_flag_status(flag_type, repo, arch)
    logger.debug "disabled_for #{flag_type} repo:#{repo} arch:#{arch} state:#{state}"
    state.to_sym == :disable
  end

  def find_flag_status(flag_type, repo, arch)
    flags = Flag::SpecifiedFlags.new(self, flag_type)
    flags.effective_flag(repo, arch).status
  end

  def self.xml_disabled_for?(xmlhash, flagtype)
    Rails.logger.debug { "xml_disabled? #{xmlhash.inspect}" }
    disabled = false
    xmlhash.elements(flagtype.to_s) do |xmlflags|
      xmlflags.keys.each do |status|
        disabled = true if status == 'disable'
        return false if status == 'enable'
      end
    end
    disabled
  end

  def self.render(my_model, xml)
    flags_sorted = my_model.flags.includes(:architecture).group_by(&:flag)

    # the defined order is by type
    FlagHelper.flag_types.each do |flag_name|
      next unless flags_sorted.key?(flag_name)

      xml.send(:"#{flag_name}_") do # avoid class with 'build' function
        flags_sorted[flag_name].each { |flag| flag.to_xml(xml) }
      end
    end
  end
end
