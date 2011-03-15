class Package < ActiveXML::Base
   
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

  def save_file(opt = {})
    content = "" # touch an empty file first
    content = opt[:file].read if opt[:file]
    logger.debug "storing file: #{content}, filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    put_opt = Hash.new
    put_opt[:package] = self.name
    put_opt[:project] = @init_options[:project]
    put_opt[:filename] = opt[:filename]
    put_opt[:comment] = opt[:comment]
    put_opt[:keeplink] = opt[:expand] if opt[:expand]

    fc = FrontendCompat.new
    fc.put_file(content, put_opt)
    return true
  end

  def remove_file( name, expand = nil )
    delete_opt = Hash.new
    delete_opt[:package] = self.name
    delete_opt[:project] = @init_options[:project]
    delete_opt[:filename] = name
    delete_opt[:keeplink] = expand if expand

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
    add_element('person', 'userid' => opt[:userid], 'role' => opt[:role])
  end

  def add_group(opt={})
    return false unless opt[:groupid] and opt[:role]
    logger.debug "adding group '#{opt[:groupid]}', role '#{opt[:role]}' to project #{self.name}"

    if has_element?(:remoteurl)
      elem_cache = split_data_after :remoteurl
    else
      elem_cache = split_data_after :description
    end

    # add the new group
    add_element('group', 'groupid' => opt[:groupid], 'role' => opt[:role])
    merge_data elem_cache
  end

  #removes persons based on attributes
  def remove_person(person, role=nil)
  end

  def remove_persons( opt={} )
    xpath="//person"
    if not opt.empty?
      opt_arr = []
      opt.each {|k,v| opt_arr << "@#{k}='#{v}'" unless v.nil? or v.empty?}
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing persons using xpath '#{xpath}'"
    data.find(xpath).each {|e| e.remove!}
  end

  def remove_group(opt={})
    xpath="//group"
    if not opt.empty?
      opt_arr = []
      opt.each {|k,v| opt_arr << "@#{k}='#{v}'" unless v.nil? or v.empty?}
      xpath += "[#{opt_arr.join ' and '}]"
    end
    logger.debug "removing groups using xpath '#{xpath}'"
    data.find(xpath.to_s).each {|e| e.remove!}
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

  def bugowners
    b = all_persons("bugowner")
    return nil if b.empty?
    return b
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

  def user_has_role?(userid, role)
    each_person do |p|
      return true if p.role == role and p.userid == userid
    end
    return false
  end

  def group_has_role?(groupid, role)
    each_group do |g|
      return true if g.role == role and g.groupid == groupid
    end
    return false
  end

  def users
    users = []
    each_person {|p| users.push(p.userid)}
    return users.sort.uniq
  end

  def groups
    groups = []
    each_group {|g| groups.push(g.groupid)}
    return groups.sort.uniq
  end

  def is_maintainer? userid
    has_element? "person[@role='maintainer' and @userid = '#{userid}']"
  end

  def can_edit? userid
    return false unless userid
    return true if is_maintainer? userid
    return true if p=Project.find_cached(project) and p.can_edit? userid
    Person.find_cached(userid).is_admin?
  end

  def free_directory( rev=nil, expand=false )
    # just free current revision cache
    Directory.free_cache( :project => project, :package => name, :rev => rev, :expand => expand )
  end

  def linkinfo
    unless @linkinfo
      begin
        link = Directory.find_cached( :project => project, :package => name)
        @linkinfo = link.linkinfo if link && link.has_element?('linkinfo')
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @linkinfo
  end

  def linked_to
    return [linkinfo.project, linkinfo.package] if linkinfo
    return []
  end

  def self.current_xsrcmd5(project, package )
    Directory.free_cache( :project => project, :package => package )
    dir = Directory.find_cached( :project => project, :package => package )
    return nil unless dir
    return nil unless dir.has_attribute? :xsrcmd5
    return dir.xsrcmd5
  end

  def self.current_rev(project, package )
    Directory.free_cache( :project => project, :package => package )
    dir = Directory.find_cached( :project => project, :package => package )
    return nil unless dir
    return nil unless dir.has_attribute? :rev
    return dir.rev
  end

  def cacheAllCommits
    commit( nil, true )
    return true
  end

  def commit( rev = nil, cacheAll = nil )
    if rev and rev.to_i < 0
      # going backward from not yet known current revision, find out ...
      r = Package.current_rev(project, name).to_i + rev.to_i + 1
      rev = r.to_s
      return nil if rev.to_i < 1
    end
    rev = Package.current_rev(project, name) unless rev

    if rev and not cacheAll
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(name)}/_history?rev=#{CGI.escape(rev)}"
      cache_key = "Commit/#{project}/#{name}/#{rev}"
      c = Rails.cache.fetch(cache_key, :expires_in => 30.minutes)
      if c
        return c
      end
    else
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(name)}/_history"
    end


    frontend = ActiveXML::Config::transport_for( :package )
    begin
      answer = frontend.direct_http URI(path), :method => "GET"
    rescue
      return nil
    end

    c = {}
    doc = XML::Parser.string(answer).parse.root
    doc.find("/revisionlist/revision").each do |s|
         c[:revision]= s.attributes["rev"]
         c[:user]    = s.find_first("user").content
         c[:version] = s.find_first("version").content
         c[:time]    = s.find_first("time").content
         c[:srcmd5]  = s.find_first("srcmd5").content
         c[:comment] = nil
         c[:requestid] = nil
         if comment=s.find_first("comment")
           c[:comment] = comment.content
         end
         if requestid=s.find_first("requestid")
           c[:requestid] = requestid.content
         end
         Rails.cache.fetch( cache_key ) { c } if cache_key and c[:revision]
    end

    return nil unless c[:revision]
    return c
  end

  def files( rev = nil, expand = nil )
    # files whose name ends in the following extensions should not be editable and viewable
    no_edit_ext = %w{ .bz2 .dll .exe .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .pdf .pk3 .png .ps .rpm .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .xpm .xz .z .zip }
    files = []
    p = {}
    p[:project] = project
    p[:package] = name
    p[:expand]  = expand  if expand
    p[:rev]     = rev     if rev
    begin
      dir = Directory.find(p)
    rescue
      begin
        # retry without merging latest base version
        p[:linkrev] = 'base'
        dir = Directory.find(p)
      rescue
        return files
      end
    end
    return files unless dir
    @linkinfo = dir.linkinfo if dir.has_element? 'linkinfo'
    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:ext] = Pathname.new(file[:name]).extname
      file[:editable] = ((not no_edit_ext.include?( file[:ext].downcase )) and not file[:name].match(/^_service[_:]/) and file[:size].to_i < 2**20)  # max. 1 MB
      file[:viewable] = ((not no_edit_ext.include?( file[:ext].downcase )) and file[:size].to_i < 2**20)  # max. 1 MB
      file[:srcmd5] = dir.srcmd5
      files << file
    end
    return files
  end

end

