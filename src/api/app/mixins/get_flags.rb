module GetFlags
  # TODO: used by bento. Remove when dropping old UI.
  # Returns a hash of arrays, sorted by repository.
  # The arrays contain Flag objects of type, sorted by architecture.
  # Like:
  # {all: [Flag, Flag-i586, Flag-x86_64], 13.2: [Flag, Flag-i585, Flag-x86_64]}
  def get_flags(flag_type)
    the_flags = {}

    # [nil] is a placeholder for "all" repositories
    [nil].concat(repositories.pluck(:name)).each do |repository|
      the_flags[repository] = []
      # [nil] is a placeholder for "all" architectures
      [nil].concat(architectures.reorder('name').distinct).each do |architecture|
        architecture_id = architecture ? architecture.id : nil
        flag = flags.where(flag: flag_type).where(repo: repository).where(architecture_id: architecture_id).first
        # If there is no flag create a temporary one.
        unless flag
          flag = flags.new(flag: flag_type, repo: repository, architecture: architecture)
          flag.status = flag.effective_status
        end
        the_flags[repository] << flag
      end
    end
    the_flags['all'] = the_flags.delete(nil)

    the_flags
  end

  def specified_flags(flag_type)
    all_flags = flags.where(flag: flag_type).group_by(&:repo)

    all_flags.each do |repo, flag_array|
      all_flags[repo] = {}
      flag_array.each do |flag|
        all_flags[repo][flag.architecture.try(&:name)] = flag
      end
    end
  end
end
