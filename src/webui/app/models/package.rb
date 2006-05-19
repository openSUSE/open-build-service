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
   
    fc = FrontendCompat.new
    @pending_files.each do |file|
      logger.debug "storing file: #{file.inspect}"
      put_opt[:filename] = file[0]
      fc.put_file file[1].read, put_opt
    end
    logger.debug "finished storing files"

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
    @data.add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]

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
    @data.each_element(xpath) do |e|
      @data.delete_element e
    end
  end

end
