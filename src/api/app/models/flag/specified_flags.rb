class Flag::SpecifiedFlags
  def initialize(prj_or_pkg, flag_type)
    @flags = {}
    @flags[:object] = specified_flags(prj_or_pkg, flag_type)
    @flags[:default] = Flag.new(flag: flag_type, status: FlagHelper.default_for(flag_type))
    @flags[:project] = specified_flags(prj_or_pkg.project, flag_type) if prj_or_pkg.is_a?(Package)
  end

  def effective_flag(repository, architecture)
    dig_flag(:effective_flag_for, repository, architecture)
  end

  def default_flag(repository, architecture)
    dig_flag(:default_flag_for, repository, architecture)
  end

  def set_by_user?(repository, architecture)
    @flags[:object].dig(repository, architecture).present?
  end

  private

  def dig_flag(callback_function, repository, architecture)
    flag = send(callback_function, @flags[:object], repository, architecture)
    flag ||= send(callback_function, @flags[:project], repository, architecture) if @flags[:project]
    flag || @flags[:default]
  end

  def effective_flag_for(flags, repository, architecture)
    flags.dig(repository, architecture) || flags.dig(repository, nil) || flags.dig(nil, architecture) || flags.dig(nil, nil)
  end

  # It finds out how the table would look like if the flag was not set.
  # In case of specific flags this means lookup the rest, for flags that are
  # only specifying one direction, we need to look at the overall state
  # (default state is handled in the function above).
  def default_flag_for(flags, repository, architecture)
    if repository && architecture
      flags.dig(repository, nil) || flags.dig(nil, architecture) || flags.dig(nil, nil)
    elsif architecture || repository
      flags.dig(nil, nil)
    end
  end

  def specified_flags(prj_or_pkg, flag_type)
    all_flags = prj_or_pkg.flags.where(flag: flag_type).includes(:architecture).group_by(&:repo)

    all_flags.each do |repo, flag_array|
      all_flags[repo] = {}
      flag_array.each do |flag|
        all_flags[repo][flag.architecture.try(&:name)] = flag
      end
    end
  end
end
