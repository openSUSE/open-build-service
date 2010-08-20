class Package < ActiveXML::Base
   
  belongs_to :project

  handles_xml_element 'package'

  #cache variables
  attr_accessor :linkinfo

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  def initialize(*args)
    super(*args)
    @bf_updated = false
    @pf_updated = false
    @df_updated = false
    @uf_updated = false
  end

  def to_s
    name.to_s
  end

  def save_file( opt = {} )
    file = opt[:file]
    logger.debug "storing file: #{file.inspect}, filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    put_opt = Hash.new
    put_opt[:package] = self.name
    put_opt[:project] = @init_options[:project]
    put_opt[:filename] = opt[:filename]
    put_opt[:comment] = opt[:comment]
    put_opt[:expand] = "1" if opt[:expand]

    fc = FrontendCompat.new
    fc.put_file file.read, put_opt
    true
  end

  def remove_file( name, expand = nil )
    delete_opt = Hash.new
    delete_opt[:package] = self.name
    delete_opt[:project] = @init_options[:project]
    delete_opt[:filename] = name
    delete_opt[:expand] = "1" if expand

    begin
       FrontendCompat.new.delete_file delete_opt
       true
    rescue ActiveXML::Transport::NotFoundError
       false
    end 
  end

  def add_person( opt={} )
    return false unless opt[:userid] and opt[:role]
    logger.debug "adding person '#{opt[:userid]}', role '#{opt[:role]}' to package #{self.name}"

    #add the new person
    add_element 'person', 'userid' => opt[:userid], 'role' => opt[:role]
  end

  #removes persons based on attributes
  def remove_persons( opt={} )
    xpath="//person"
    if not opt.empty?
      opt_arr = []
      opt.each do |k,v|
        opt_arr << "@#{k}='#{v}'"
      end
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.find(xpath).each {|e| e.remove! }
  end


  def set_url( new_url )
    logger.debug "set url #{new_url} for package #{self.name} (project #{self.project})"
    add_element 'url' unless has_element? :url
    url.text = new_url
    save
  end


  def remove_url
    logger.debug "remove url from package #{self.name} (project #{self.project})"
    data.find('//url').each { |e| e.remove! }
    save
  end

  def bugowner
    b = all_persons("bugowner")
    return b.first if b
    return nil
  end

  def linking_packages
    opt = Hash.new
    opt[:project] = self.project
    opt[:package] = self.name
    opt[:cmd] = "showlinked"
    fc = FrontendCompat.new
    answer = fc.do_post nil, opt

    doc = XML::Parser.string(answer).parse
    result = []
    doc.find("/collection/package").each do |e|
      hash = {}
      hash[:project] = e.attributes["project"]
      hash[:package] = e.attributes["name"]
      result.push( hash )
    end

    return result
  end

  def all_persons( role )
    ret = Array.new
    each_person do |p|
      if p.role == role
        ret << p.userid.to_s
      end
    end
    return ret
  end

  def all_groups( role )
    ret = Array.new
    each_group do |p|
      if p.role == role
        ret << p.groupid.to_s
      end
    end
    return ret
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def free_directory
    # just free current revision cache
    Directory.free_cache( :project => project, :package => name, :expand => nil )
    Directory.free_cache( :project => project, :package => name, :expand => "1" )
  end

  def linkinfo
    unless @linkinfo
      begin
        link = Directory.find_cached( :project => project, :package => name)
        @linkinfo = link.linkinfo if link.has_element? 'linkinfo'
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @linkinfo
  end

  def linked_to
    return [linkinfo.project, linkinfo.package] if linkinfo
    return []
  end

  def self.current_rev(project, package )
    Directory.free_cache( :project => project, :package => package )
    dir = Directory.find_cached( :project => project, :package => package )
    return nil unless dir
    return nil unless dir.has_attribute? :rev
    return dir.rev
  end

  def commit( rev = nil )
    if rev and rev.to_i < 0
      # going backward from not yet known current revision, find out ...
      r = Package.current_rev(project, name).to_i + rev.to_i + 1
      rev = r.to_s
      return nil if rev.to_i < 1
    end
    rev = Package.current_rev(project, name) unless rev

    path = "/source/#{CGI.escape(project)}/#{CGI.escape(name)}/_history?rev=#{CGI.escape(rev)}"

    frontend = ActiveXML::Config::transport_for( :package )
    answer = frontend.direct_http URI(path), :method => "GET"

    c = {}
    doc = XML::Parser.string(answer).parse.root
    doc.find("/revisionlist/revision").each do |s|
         c[:revision]= s.attributes["rev"]
         c[:user]    = s.find_first("user").content
         c[:version] = s.find_first("version").content
         c[:time]    = s.find_first("time").content
         c[:srcmd5]  = s.find_first("srcmd5").content
         if comment=s.find_first("comment")
           c[:comment] = comment.content
         end
    end

    return nil unless [:revision]
    return c
  end

  def files( rev = nil, expand = nil )
    # files whose name ends in the following extensions should not be editable
    no_edit_ext = %w{ .bz2 .dll .exe .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .pdf .pk3 .png .ps .rpm .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .xpm .xz .z .zip }
    files = []
    p = {}
    p[:project] = project
    p[:package] = name
    p[:expand]  = "1"     if expand == "true"
    p[:rev]     = rev     if rev
    dir = Directory.find_cached(p)
    return files unless dir
    @linkinfo = dir.linkinfo if dir.has_element? 'linkinfo'
    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:ext] = Pathname.new(file[:name]).extname
      file[:editable] = ((not no_edit_ext.include?( file[:ext].downcase )) and not file[:name].match(/^_service:/) and file[:size].to_i < 2**20)  # max. 1 MB
      file[:srcmd5] = dir.srcmd5
      files << file
    end
    return files
  end

end

