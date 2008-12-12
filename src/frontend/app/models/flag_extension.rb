module FlagExtension
  def enabled_for?(repo, arch)
    state = find_flag_state(repo, arch)
    return state == :enabled ? true : false
  end

  def disabled_for?(repo, arch)
    state = find_flag_state(repo, arch)
    return state == :disabled ? true : false
  end

  def find_flag_state(repo, arch)
    state = :default

    each do |flag|
      state = flag.state if flag.is_relevant_for?(repo, arch)
    end

    if state == :default
      if proxy_owner.kind_of? DbPackage
        logger.debug "flagcheck: package has default state, checking project"
        state = proxy_owner.db_project.__send__(proxy_reflection.name).find_flag_state(repo, arch)
      else
        state = proxy_reflection.klass.default_state
      end
    end

    return state
  end
end
