class Package < ActiveXML::Base
  belongs_to :project
  
  def to_s
    name.to_s
  end

  def save_file( opt = {} )
    file = opt[:file]

    logger.debug "storing file: #{file.inspect}"

    put_opt = Hash.new
    put_opt[:package] = self.name    
    put_opt[:project] = @init_options[:project]
    put_opt[:filename] = opt[:filename]
   
    fc = FrontendCompat.new
    fc.put_file file.read, put_opt
    true
  end

  def remove_file( name )
    delete_opt = Hash.new
    delete_opt[:package] = self.name    
    delete_opt[:project] = @init_options[:project]
    delete_opt[:filename] = name

    FrontendCompat.new.delete_file delete_opt
    
    true
  end

  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to package #{self.name}"

    if( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    #add the new person
    data.add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]

    merge_data elem_cache
  end

  #removes persons based on attributes
  def remove_persons( opt={} )
    xpath="person"
    if not opt.empty?
      opt_arr = []
      opt.each do |k,v|
        opt_arr << "@#{k}='#{v}'"
      end
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.each_element(xpath) do |e|
      data.delete_element e
    end
  end


  # disable building of this package for the specified repo / arch / repo/arch-combination
  def disable_build( opt={} )
    logger.debug "disable building of package #{self.name} for #{opt[:repo]} #{opt[:arch]}"

    if( has_element? :disable )
      elem_cache = split_data_after :disable
    else
      elem_cache = split_data_after :person
    end

    if opt[:repo] and opt[:arch]
      data.add_element 'disable', 'repository' => opt[:repo], 'arch' => opt[:arch]
    else
      if opt[:repo]
        data.add_element 'disable', 'repository' => opt[:repo]
      elsif opt[:arch]
        data.add_element 'disable', 'arch' => opt[:arch]
      else
        data.add_element 'disable'
      end
    end

    merge_data elem_cache
    begin
      save
    rescue
      return false
    end
  end


  # enable building / remove disable-entry
  def enable_build( opt={} )
    if opt[:repo] && opt[:arch]
      xpath="disable[@repository='#{opt[:repo]}' and @arch='#{opt[:arch]}']"
    elsif opt[:repo]
      xpath="disable[@repository='#{opt[:repo]}' and not(@arch)]"
    elsif opt[:arch]
      xpath="disable[@arch='#{opt[:arch]}' and not(@repository)]"
    else
      xpath="//disable[count(@*) = 0]"
    end
    logger.debug "enable building of package #{self.name} using xpath '#{xpath}'"
    data.each_element(xpath) do |e|
      data.delete_element e
    end
    save
  end


  # get all <disable .../> -tags from xml-data of this package
  def get_disable_tags
    xpath="//disable"
    return data.get_elements(xpath).join("\n")
  end


  # replace all <disable .../> -tags in this package with new ones
  def replace_disable_tags( new_disable_tags )
    remove_disable_tags if not new_disable_tags.empty?
    data.add_text new_disable_tags
    begin
      save
    rescue
      logger.debug 'error: invalid xml for disable-tags'
      return false
    end
  end


  def remove_disable_tags
    data.get_elements("//disable").each { |e| data.delete_element e }
  end


end
