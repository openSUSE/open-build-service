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
    state = proxy_reflection.klass.default_state
    each do |flag|
      state = flag.state if flag.is_relevant_for?(repo, arch)
    end
    return state
  end
end
