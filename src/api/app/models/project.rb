class Project < ActiveXML::Base
  def add_person( opt={} )
    defaults = {:role => 'maintainer'}
    opt = defaults.merge opt

    userid = opt[:userid]
    role = opt[:role]

    logger.debug "add_person: role: #{role.inspect}"

    raise "add_person needs :userid argument" unless opt[:userid]

    if( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    add_element( 'person', 'userid' => opt[:userid], 'role' => opt[:role] )

    merge_data elem_cache
  end

  def name=(new_name)
    self.attributes['name'] = new_name.to_s
  end

  def title=(new_title)
    self.title.data.text = new_title.to_s
  end

  def description=(new_desc)
    self.description.data.text = new_desc.to_s
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
