class WebuiPackage < Webui::Node
   
  handles_xml_element 'package'

  #cache variables
  attr_accessor :linkinfo

  attr_accessor :bf_updated
  attr_accessor :pf_updated
  attr_accessor :df_updated
  attr_accessor :uf_updated

  attr_writer :name, :project

  BINARY_EXTENSIONS = %w{.0 .bin .bin_mid .bz .bz2 .ccf .cert .chk .der .dll .exe .fw .gem .gif .gz .jar .jpeg .jpg .lzma .ogg .otf .oxt .pdf .pk3 .png .ps .rpm .sig .svgz .tar .taz .tb2 .tbz .tbz2 .tgz .tlz .txz .ucode .xpm .xz .z .zip .ttf}

  def initialize(*args)
    super(*args)
    @bf_updated = false
    @pf_updated = false
    @df_updated = false
    @uf_updated = false
    @linkinfo = nil
    @serviceinfo = nil
  end

  def self.make_stub(opt)
    doc = ActiveXML::Node.new('<package/>')
    doc.set_attribute('name', opt[:name])
    doc.add_element 'title'
    doc.add_element 'description'
    doc
  end

  def to_s
    name
  end

  def to_param
    name
  end

  def name
    @name ||= value('name')
  end

  def project
    @project ||= value('project') 
  end

  def last_save_error
    @last_error
  end

  def save_file(opt = {})
    content = '' # touch an empty file first
    content = opt[:file] if opt[:file]
    logger.debug "storing file: filename: #{opt[:filename]}, comment: #{opt[:comment]}"

    put_opt = Hash.new
    put_opt[:package] = self.name
    put_opt[:project] = self.project
    put_opt[:filename] = opt[:filename]
    put_opt[:comment] = opt[:comment]
    put_opt[:keeplink] = opt[:expand] if opt[:expand]

    fc = FrontendCompat.new
    begin
      fc.put_file(content, put_opt)
      @last_error = nil
    rescue ActiveXML::Transport::Error => e
      @last_error = e
      return false
    end
    return true
  end

  def remove_file( name, expand = nil )
    delete_opt = Hash.new
    delete_opt[:package] = self.name
    delete_opt[:project] = self.api_obj.project.name
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

    # add the new group
    add_element('group', 'groupid' => opt[:groupid], 'role' => opt[:role])
  end

  def bugowners
    return users('bugowner')
  end

  def user_has_role?(user, role)
    user && api_obj.relationships.where(user: user, role_id: Role.rolecache[role]).exists?
  end

  def group_has_role?(groupid, role)
    each_group do |g|
      return true if g.role == role and g.groupid == groupid
    end
    return false
  end

  def users(role = nil)
    rels = api_obj.relationships
    rels = rels.where(role: Role.rolecache[role]) if role
    users = rels.users.pluck(:user_id)
    rels.groups.each do |g|
      users << g.groups_users.pluck(:user_id)
    end
    User.where(id: users.flatten.uniq)
  end

  def groups(role = nil)
    rels = api_obj.relationships
    rels = rels.where(role: Role.rolecache[role]) if role
    Group.where(id: rels.groups.pluck(:group_id).uniq)
  end

  def linkinfo
    unless @linkinfo
      begin
        dir = Directory.find( :project => project, :package => name)
        @linkinfo = dir.linkinfo if dir && dir.has_element?('linkinfo')
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @linkinfo
  end

  def serviceinfo
    unless @serviceinfo
      begin
        dir = Directory.find( :project => project, :package => name)
        @serviceinfo = dir.serviceinfo if dir && dir.has_element?('serviceinfo')
      rescue ActiveXML::Transport::NotFoundError
      end
    end
    @serviceinfo
  end

  def parse_all_history
    answer = api_obj.source_file('_history')

    doc = Xmlhash.parse(answer)
    doc.elements('revision') do |s|
      Rails.cache.write(["history", api_obj, s['rev']], s)
    end
  end

  def commit( rev = nil )
    if rev and rev.to_i < 0
      # going backward from not yet known current revision, find out ...
      r = api_obj.rev.to_i + rev.to_i + 1
      rev = r.to_s
      return nil if rev.to_i < 1
    end
    rev ||= api_obj.rev

    cache_key = ["history", api_obj, rev]
    c = Rails.cache.read(cache_key)
    return c if c

    parse_all_history
    # now it has to be in cache
    Rails.cache.read(cache_key)
  end

  def files( rev = nil, expand = nil )
    files = []
    p = {}
    p[:project] = project
    p[:package] = name
    p[:expand]  = expand  if expand
    p[:rev]     = rev     if rev
    dir = Directory.find(p)
    return files unless dir
    @linkinfo = dir.linkinfo if dir.has_element? 'linkinfo'
    @serviceinfo = dir.serviceinfo if dir.has_element? 'serviceinfo'
    dir.each_entry do |entry|
      file = Hash[*[:name, :size, :mtime, :md5].map {|x| [x, entry.send(x.to_s)]}.flatten]
      file[:viewable] = !WebuiPackage.is_binary_file?(file[:name]) && file[:size].to_i < 2**20  # max. 1 MB
      file[:editable] = file[:viewable] && !file[:name].match(/^_service[_:]/)
      file[:srcmd5] = dir.srcmd5
      files << file
    end
    return files
  end

  def developed_packages
    packages = []
    candidates = Webui::Collection.find(:id, :what => 'package', :predicate => "[devel/@package='#{name}' and devel/@project='#{project}']")
    candidates.each do |candidate|
      packages << candidate unless candidate.linkinfo
    end
    return packages
  end

  def self.is_binary_file?(filename)
    BINARY_EXTENSIONS.include?(File.extname(filename).downcase)
  end

  def self.attributes(project_name, package_name)
    path = "/source/#{project_name}/#{package_name}/_attribute/"
    res = ActiveXML::api.direct_http(URI("#{path}"))
    return Webui::Collection.new(res)
  end

  def attributes
    Package.attributes(self.project, self.name)
  end

  def self.has_attribute?(project_name, package_name, attribute_namespace, attribute_name)
    self.attributes(project_name, package_name).each do |attr|
      return true if attr.namespace == attribute_namespace && attr.name == attribute_name
    end
    return false
  end

  def linkdiff
    begin
      path = "/source/#{self.project}/#{self.name}?cmd=linkdiff&view=xml&withissues=1"
      res = ActiveXML::api.direct_http(URI("#{path}"), :method => 'POST', :data => '')
      return Webui::Sourcediff.new(res)
    rescue ActiveXML::Transport::Error
      return nil
    end
  end

  def self.find(name, opts)
    project = opts[:project].to_param
    name = name.to_param
    begin
      ap = Package.get_by_project_and_name(project, name, use_source: false)
    rescue Package::UnknownObjectError, Project::UnknownObjectError => e
      Rails.logger.debug "NOT FOUND #{e.inspect}"
      return nil
    end
    p = WebuiPackage.new  '<package/>'
    p.api_obj = ap
    p.name = name
    p.project = project
    p.instance_variable_set('@init_options', project: project, name: name)
    p
  end

  def parse(data)
    if @api_obj
      data = api_obj.to_axml
    end
    super(data)
  end

  attr_writer :api_obj
  def api_obj
    @api_obj ||= Package.find_by_project_and_name(project, name)
  end

end

