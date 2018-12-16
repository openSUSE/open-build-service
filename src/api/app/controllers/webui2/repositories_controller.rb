module Webui2::RepositoriesController
  def webui2_index
    @flags = {}
    [:build, :debuginfo, :publish, :useforbuild].each do |flag_type|
      @flags[flag_type] = {}
      set_flag_for(@flags[flag_type], flag_type)
    end

    @user_can_set_flags = policy(@project).update?

    @architectures = @project.architectures.reorder('name')
    @repositories = @project.repositories.includes(:path_elements, :download_repositories)
  end

  def webui2_create_flag
    @flags = {}
    set_flag_for(@flags, @flag.flag.to_sym)
  end

  def webui2_toggle_flag
    @flags = {}
    set_flag_for(@flags, @flag.flag.to_sym)
  end

  def webui2_remove_flag
    @flags = {}
    set_flag_for(@flags, @flag.flag.to_sym)
  end

  # TODO: This should be private
  def set_flag_for(flags, flag_type)
    flags[:object] = @main_object.specified_flags(flag_type)
    flags[:default] = Flag.new(flag: flag_type, status: Flag.default_status(flag_type))
    flags[:project] = @project.specified_flags(flag_type) if @main_object.is_a?(Package)
  end
end
