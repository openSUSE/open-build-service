class Package < ActiveXML::Base
  #validates_presence_of :description
  belongs_to :project
  
  def to_s
    name.to_s
  end

  def add_and_save_file( opt={} )
    return false if not add_file( opt )
    return false if not save_files
    true
  end
  
  def add_file(opt={})
    return nil if opt == {}
    file_tag = REXML::Element.new 'file'
    
    fname = REXML::Element.new 'filename'
    fname.text = opt[:filename]
    file_tag.add_element fname
    
    ftype = REXML::Element.new 'filetype'
    ftype.text = opt[:filetype]
    file_tag.add_element ftype
    
    if opt[:revision]
      rev = REXML::Element.new 'revision'
      rev.text = opt[:revision]
      file_tag.add_element rev
    end

    if( has_element? :file )
      elem_cache = split_data_after :file
    elsif( has_element? :person )
      elem_cache = split_data_after :person
    else
      elem_cache = split_data_after :description
    end

    @data.add_element file_tag

    merge_data elem_cache

    @pending_files ||= []
    @pending_files << [opt[:filename], opt[:file]]
  end

  def save_files
    return true if not @pending_files
   
    put_opt = Hash.new
    put_opt[:package] = self.name
    
    #FIXME: hack
    put_opt[:project] = @project
    
    @pending_files.each do |file|
      logger.debug "storing file: #{file.inspect}"
      put_opt[:filename] = file[0]
      @@transport.put_file file[1].read, put_opt
    end
    logger.debug "finished storing files"
    @pending_files = []
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
