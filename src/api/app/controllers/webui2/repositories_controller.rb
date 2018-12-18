module Webui2::RepositoriesController
  def webui2_index
    @flags = {}
    [:build, :debuginfo, :publish, :useforbuild].each do |flag_type|
      @flags[flag_type] = Flag::SpecifiedFlags.new(@main_object, flag_type)
    end

    @user_can_set_flags = policy(@project).update?

    @architectures = @project.architectures.reorder('name')
    @repositories = @project.repositories.includes(:path_elements, :download_repositories)
  end

  def webui2_create_flag
    @flags = Flag::SpecifiedFlags.new(@main_object, @flag.flag)
  end

  def webui2_toggle_flag
    @flags = Flag::SpecifiedFlags.new(@main_object, @flag.flag)
  end

  def webui2_remove_flag
    @flags = Flag::SpecifiedFlags.new(@main_object, @flag.flag)
  end
end
