module Webui::RepositoryHelper
  def effective_flag(flags, repository, architecture)
    dig_flag(:effective_flag_for, flags, repository, architecture)
  end

  def default_flag(flags, repository, architecture)
    dig_flag(:default_flag_for, flags, repository, architecture)
  end

  def flag_set_by_user?(flags, repository, architecture)
    flags[:object].dig(repository, architecture).present?
  end

  def html_id_for_flag(flag_type, repository, architecture)
    # repository and architecture can be nil
    valid_xml_id("flag-#{flag_type}-#{repository}-#{architecture}")
  end

  # TODO: This should be private
  def dig_flag(callback_function, flags, repository, architecture)
    flag = send(callback_function, flags[:object], repository, architecture)
    flag ||= send(callback_function, flags[:project], repository, architecture) if flags[:project]
    flag || flags[:default]
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
end
