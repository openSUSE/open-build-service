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
    #FIXME: hack
    put_opt[:project] = @project
    put_opt[:filename] = opt[:filename]

    @@transport.put_file file.read, put_opt

    logger.debug "finished storing files"

    true
  end

  def remove_file( name )
    delete_opt = Hash.new
    delete_opt[:package] = self.name    
    #FIXME: hack
    delete_opt[:project] = @project
    delete_opt[:filename] = name

    @@transport.delete_file delete_opt
    
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
