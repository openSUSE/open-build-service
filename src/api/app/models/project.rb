class Project < ActiveXML::Base
  def add_person( opt={} )
    defaults = {:role => 'maintainer'}
    opt = defaults.merge opt

    userid = opt[:userid]
    role = opt[:role]

    logger.debug "add_person: role: #{role.inspect}"

    raise "add_person needs :userid argument" unless opt[:userid]

    add_element( 'person', 'userid' => opt[:userid], 'role' => opt[:role] )
  end

  def name=(new_name)
    self.attributes['name'] = new_name.to_s
  end

  def title=(new_title)
    self.title.text = new_title.to_s
  end

  def description=(new_desc)
    self.description.text = new_desc.to_s
  end

  def disabled_for?(flag_type)
    # very simple method, just for sourceaccess and access usable
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
