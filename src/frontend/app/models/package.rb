class Package < ActiveXML::Base
  def parent_project_name
    @init_options[:project]
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

    if( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    @data.add_element( 'person', 'userid' => opt[:userid], 'role' => opt[:role] )

    merge_data elem_cache
  end


  def update_timestamp
    # save will call DbPackage.store_axml() through ActiveXML::Transport.save()
    # which will do DbPackage.update_timestamp() and DbPackage.save()
    save
  end


end
