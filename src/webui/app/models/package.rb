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

    elem_cache = get_elements_before :person

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

    fulldata = REXML::Document.new( data.to_s )
    elem_cache = get_elements_before :disable

    if opt[:repo] and opt[:arch]
      if fulldata.root.get_elements("disable[@repository='#{opt[:repo]}' and @arch='#{opt[:arch]}']").empty?
        data.add_element 'disable', 'repository' => opt[:repo], 'arch' => opt[:arch]
      else return false
      end
    else
      if opt[:repo]
        if fulldata.root.get_elements("disable[@repository='#{opt[:repo]}' and not(@arch)]").empty?
          data.add_element 'disable', 'repository' => opt[:repo]
        else return false
        end
      elsif opt[:arch]
        if fulldata.root.get_elements("disable[@arch='#{opt[:arch]}' and not(@repository)]").empty?
          data.add_element 'disable', 'arch' => opt[:arch]
        else return false
        end
      else
        if fulldata.root.get_elements("//disable[count(@*) = 0]").empty?
          data.add_element 'disable'
        else return false
        end
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


  def set_url( new_url )
    logger.debug "set url #{new_url} for package #{self.name} (project #{self.project})"
    if( has_element? :url )
      url.data.text = new_url
    else
      elem_cache = get_elements_before :url
      data.add_element 'url'
      merge_data elem_cache
      url.data.text = new_url
    end
    save
  end


  def remove_url
    logger.debug "remove url from package #{self.name} (project #{self.project})"

    data.each_element('//url') do |e|
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
    remove_disable_tags
    data.add_text new_disable_tags if not new_disable_tags.empty?
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



  private



  def get_elements_before( element )
    # this is a helper method for inserting elements at the right place in xml,
    # it's necessary because the order of elements is important.
    # wished order:
    element_order = [
      :title, :description, :person, :disable, :notify, :delete_notify,
      :url, :group, :license, :keyword, :file
    ]
    until element_order.pop == element or element_order.empty? do end
    elem_cache = []
    element_order.reverse!
    element_order.each do |e|
      if has_element? e
        elem_cache = split_data_after e
        break
      end
    end
    return elem_cache
  end


end

