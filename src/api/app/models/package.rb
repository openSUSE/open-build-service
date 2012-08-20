class Package < ActiveXML::Base
  def parent_project_name
    @init_options[:project]
  end

  def name=(new_name)
    set_attribute("name", new_name.to_s)
  end

  def project=(new_project)
    set_attribute("project", new_project.to_s)
  end

  def parent_project
    Project.find parent_project_name
  end

  def add_person( opt={} )
    defaults = {:role => 'maintainer'}
    opt = defaults.merge opt

    userid = opt[:userid]
    role = opt[:role]

    logger.debug "add_person: role: #{role.inspect}"

    raise "add_person needs :userid argument" unless opt[:userid]
    add_element( 'person', 'userid' => opt[:userid], 'role' => opt[:role] )
  end

  def remove_all_persons
    self.each_person do |e|
      delete_element e
    end
  end

  def remove_all_groups
    self.each_group do |e|
      delete_element e
    end
  end

  def remove_devel_project
    self.each_devel do |e|
      delete_element e
    end
  end

  def set_devel( opt={} )
    remove_devel_project
    add_element( 'devel', 'project' => opt[:project], 'package' => opt[:package] )
  end

  def remove_all_flags
    %w(build publish debuginfo useforbuild).each do |flag|
      send('each_' + flag) do |e|
        delete_element e
      end
    end
  end

  def disabled_for?(flag_type)
    # very simple method, just for sourceaccess usable
    disabled = false
    if self.has_element? flag_type
      self.send(flag_type).each do |f|
        disabled = true if f.element_name == "disable"
        return false if f.element_name == "enable"
      end
    end
    return disabled
  end

end
