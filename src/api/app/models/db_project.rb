require 'opensuse/backend'

class DbProject < ActiveRecord::Base
  class SaveError < Exception; end

  has_many :project_user_role_relationships, :dependent => :destroy
  has_many :project_group_role_relationships, :dependent => :destroy
  has_many :db_packages, :dependent => :destroy
  has_many :attribs, :dependent => :destroy
  has_many :repositories, :dependent => :destroy
  has_many :messages, :as => :object, :dependent => :destroy

  has_many :develpackages, :class_name => "DbPackage", :foreign_key => 'develproject_id'

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :downloads, :dependent => :destroy
  has_many :ratings, :as => :object, :dependent => :destroy

  has_many :flags
  has_many :publish_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :build_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :debuginfo_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :useforbuild_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :binarydownload_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :readaccess_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy
  has_many :privacy_flags,  :order => :position, :extend => FlagExtension, :dependent => :destroy


  def download_name
    self.name.gsub(/:/, ':/')
  end

  class << self

    def find_by_name(name)
      find :first, :conditions => ["name = BINARY ?", name]
    end

    def store_axml( project )
      dbp = nil
      DbProject.transaction do
        if not (dbp = DbProject.find_by_name project.name)
          dbp = DbProject.new( :name => project.name.to_s )
        end
        dbp.store_axml( project )
      end
      return dbp
    end

    def get_repo_list
      sql =<<-END_SQL
      SELECT p.name AS project_name, r.name AS repo_name
      FROM repositories r
      LEFT JOIN db_projects p ON r.db_project_id = p.id
      ORDER BY project_name
      END_SQL

      repolist = Repository.find_by_sql sql
      result = []
      repolist.each do |repo|
        result << "#{repo.project_name}/#{repo.repo_name}"
      end
      result
    end

    def find_remote_project(name)
      fragments = name.split(/:/)
      local_project = String.new
      remote_project = nil

      while fragments.length > 0
        remote_project = [fragments.pop, remote_project].compact.join ":"
        local_project = fragments.join ":"
        logger.debug "checking local project #{local_project}, remote_project #{remote_project}"
        lpro = DbProject.find_by_name local_project
        return lpro, remote_project unless lpro.nil? or lpro.remoteurl.nil?
      end
      return nil
    end
  end

  def store_axml( project, force=nil )
    DbProject.transaction do
      logger.debug "### name comparison: self.name -> #{self.name}, project_name -> #{project.name.to_s}"
      if self.name != project.name.to_s
        raise SaveError, "project name mismatch: #{self.name} != #{project.name}"
      end

      self.title = project.title.to_s
      self.description = project.description.to_s
      self.remoteurl = project.has_element?(:remoteurl) ? project.remoteurl.to_s : nil
      self.remoteproject = project.has_element?(:remoteproject) ? project.remoteproject.to_s : nil
      self.save!

      #--- update users ---#
      usercache = Hash.new
      self.project_user_role_relationships.each do |purr|
        h = usercache[purr.user.login] ||= Hash.new
        h[purr.role.title] = purr
      end

      project.each_person do |person|
        if usercache.has_key? person.userid
          # user has already a role in this project
          pcache = usercache[person.userid]
          if pcache.has_key? person.role
            #role already defined, only remove from cache
            pcache[person.role] = :keep
          else
            #new role
            if not Role.rolecache.has_key? person.role
              raise SaveError, "illegal role name '#{person.role}'"
            end

            ProjectUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :role => Role.rolecache[person.role],
              :db_project => self
            )
          end
        else
          if not Role.rolecache.has_key? person.role
            raise SaveError, "illegal role name '#{person.role}'"
          end

          if not (user=User.find_by_login(person.userid))
            raise SaveError, "unknown user '#{person.userid}'"
          end

          begin
            ProjectUserRoleRelationship.create(
              :user => user,
              :role => Role.rolecache[person.role],
              :db_project => self
            )
          rescue ActiveRecord::StatementInvalid => err
            if /^Mysql::Error: Duplicate entry/.match(err)
              logger.debug "user '#{person.userid}' already has the role '#{person.role}' in project '#{self.name}'"
            else
              raise err
            end
          end
        end
      end
      
      #delete all roles that weren't found in the uploaded xml
      usercache.each do |user, roles|
        roles.each do |role, object|
          next if object == :keep
          object.destroy
        end
      end

      #--- end update users ---#

      #--- update groups ---#
      groupcache = Hash.new
      self.project_group_role_relationships.each do |pgrr|
        h = groupcache[pgrr.group.login] ||= Hash.new
        h[pgrr.role.title] = pgrr
      end

      project.each_group do |ge|
        if groupcache.has_key? ge.groupid
          # group has already a role in this project
          pcache = groupcache[ge.groupid]
          if pcache.has_key? ge.role
            #role already defined, only remove from cache
            pcache[ge.role] = :keep
          else
            #new role
            if not Role.rolecache.has_key? ge.role
              raise SaveError, "illegal role name '#{ge.role}'"
            end

            ProjectGroupRoleRelationship.create(
              :group => User.find_by_login(ge.groupid),
              :role => Role.rolecache[ge.role],
              :db_project => self
            )
          end
        else
          if not Role.rolecache.has_key? ge.role
            raise SaveError, "illegal role name '#{ge.role}'"
          end

          if not (group=Group.find_by_title(ge.groupid))
            raise SaveError, "unknown group '#{ge.groupid}'"
          end

          begin
            ProjectGroupRoleRelationship.create(
              :group => group,
              :role => Role.rolecache[ge.role],
              :db_project => self
            )
          rescue ActiveRecord::StatementInvalid => err
            if /^Mysql::Error: Duplicate entry/.match(err)
              logger.debug "group '#{ge.groupid}' already has the role '#{ge.role}' in project '#{self.name}'"
            else
              raise err
            end
          end
        end
      end
      
      #delete all roles that weren't found in the uploaded xml
      groupcache.each do |group, roles|
        roles.each do |role, object|
          next if object == :keep
          object.destroy
        end
      end
      #--- end update groups ---#

      #--- update flag group ---#
      # and recreate the flag groups and flags again
      flag_compatibility_check( :project => project )

      %w(build publish debuginfo useforbuild binarydownload readaccess privacy).each do |flagtype|
        update_flags( :project => project, :flagtype => flagtype )
      end

      #add old-style-flags as build-flags
      old_flag_to_build_flag( :project => project ) if project.has_element? :disable

      dlcache = Hash.new
      self.downloads.each do |dl|
        dlcache["#{dl.architecture.name}"] = dl
      end

      project.each_download do |dl|
        if dlcache.has_key? dl.arch.to_s
          logger.debug "modifying download element, arch: #{dl.arch.to_s}"
          cur = dlcache[dl.arch.to_s]
        else
          logger.debug "adding new download entry, arch #{dl.arch.to_s}"
          cur = self.downloads.create
          self.updated_at = Time.now
        end
        cur.metafile = dl.metafile.to_s
        cur.mtype = dl.mtype.to_s
        cur.baseurl = dl.baseurl.to_s
        raise SaveError, "unknown architecture" unless Architecture.archcache.has_key? dl.arch.to_s
        cur.architecture = Architecture.archcache[dl.arch.to_s]
        cur.save!
        dlcache.delete dl.arch.to_s
      end

      dlcache.each do |arch, object|
        logger.debug "remove download entry #{arch}"
        object.destroy
      end

      #--- update repositories ---#
      repocache = Hash.new
      self.repositories.each do |repo|
        repocache[repo.name] = repo
      end

      project.each_repository do |repo|
        if not repocache.has_key? repo.name
          logger.debug "adding repository '#{repo.name}'"
          current_repo = self.repositories.create( :name => repo.name )
          self.updated_at = Time.now
        else
          logger.debug "modifying repository '#{repo.name}'"
          current_repo = repocache[repo.name]
        end

        #destroy all current pathelements
        current_repo.path_elements.each { |pe| pe.destroy }

        #recreate pathelements from xml
	position = 1
        repo.each_path do |path|
          link_repo = Repository.find_by_project_and_repo_name( path.project, path.repository )
          if link_repo.nil?
            raise SaveError, "unable to walk on path '#{path.project}/#{path.repository}'"
          end
          current_repo.path_elements.create :link => link_repo, :position => position
	  position += 1
        end

        #destroy architecture references
        current_repo.architectures.clear

        repo.each_arch do |arch|
          unless Architecture.archcache.has_key? arch.to_s
            raise SaveError, "unknown architecture: '#{arch}'"
          end
          current_repo.architectures << Architecture.archcache[arch.to_s]
        end

        repocache.delete repo.name
      end

      # delete remaining repositories in repocache
      repocache.each do |name, object|
        #find repositories that link against this one and issue warning if found
        list = PathElement.find( :all, :conditions => ["repository_id = ?", object.id] )
        unless list.empty?
          logger.debug "offending repo: #{object.inspect}"
          if force
            #replace links to the repository with links to the "deleted" project repository
            del_repo = DbProject.find_by_name("deleted").repositories[0]
            list.each do |pe|
              pe.link = del_repo
              pe.save
              #update backend
              link_prj = link_rep.db_project
              logger.info "updating project '#{link_prj.name}'"
              Suse::Backend.put_source "/source/#{link_prj.name}/_meta", link_prj.to_axml
            end
          else
            linking_repos = list.map {|x| x.repository.db_project.name+"/"+x.repository.name}.join "\n"
            raise SaveError, "Repository #{self.name}/#{name} cannot be deleted because following repos link against it:\n"+linking_repos
          end
        end
        logger.debug "deleting repository '#{name}'"
        object.destroy
        self.updated_at = Time.now
      end
      #--- end update repositories ---#
      
      store

    end #transaction
  end

  def store
    # update timestamp and save
    self.save!

    # expire cache
    Rails.cache.delete('meta_project_%d' % id)

    if write_through?
      path = "/source/#{self.name}/_meta"
      Suse::Backend.put_source( path, render_axml )
    end

    # FIXME: store attributes also to backend 
  end

  def store_attribute_axml( attrib, binary=nil )

    raise SaveError, "attribute type without a namespace " if not attrib.namespace
    raise SaveError, "attribute type without a name " if not attrib.name

    # check attribute type
    if ( not atype = AttribType.find_by_namespace_and_name(attrib.namespace, attrib.name) or atype.blank? )
      raise SaveError, "unknown attribute type '#{attrib.namespace}:#{attrib.name}'"
    end
    # verify the number of allowed values
    if atype.value_count and attrib.has_element? :value and atype.value_count != attrib.each_value.length
      raise SaveError, "Attribute: '#{attrib.namespace}:#{attrib.name}' has #{attrib.each_value.length} values, but only #{atype.value_count} are allowed"
    end
    if atype.value_count and atype.value_count > 0 and not attrib.has_element? :value
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' requires #{atype.value_count} values, but none given"
    end

    # verify with allowed values for this attribute definition
    if atype.allowed_values.length > 0
      logger.debug( "Verify value with allowed" )
      attrib.each_value.each do |value|
        found = 0
        atype.allowed_values.each do |allowed|
          if allowed.value == value.to_s
            found = 1
            break
          end
        end
        if found == 0
          raise SaveError, "attribute value #{value} for '#{attrib.name} is not allowed'"
        end
      end
    end
    # update or create attribute entry
    if a = find_attribute(attrib.namespace, attrib.name)
      a.update_from_xml(attrib)
    else
      # create the new attribute entry
      self.attribs.new(:attrib_type => atype).update_from_xml(attrib)
    end
  end

  def find_attribute( namespace, name, binary=nil )
      logger.debug "find_attribute for #{namespace}:#{name}"
      if namespace.nil?
        raise RuntimeError, "Namespace must be given"
      end
      if name.nil?
        raise RuntimeError, "Name must be given"
      end
      if binary
        raise RuntimeError, "binary packages are not allowed in project attributes"
      end
      return attribs.find(:first, :joins => "LEFT OUTER JOIN attrib_types at ON attribs.attrib_type_id = at.id LEFT OUTER JOIN attrib_namespaces an ON at.attrib_namespace_id = an.id", :conditions => ["at.name = BINARY ? and an.name = BINARY ? and ISNULL(attribs.binary)", name, namespace])
  end

  def render_attribute_axml(params)
    builder = Builder::XmlMarkup.new( :indent => 2 )

    done={};
    xml = builder.attributes() do |a|
      attribs.each do |attr|
        next if params[:name] and not attr.attrib_type.name == params[:name]
        next if params[:namespace] and not attr.attrib_type.attrib_namespace.name == params[:namespace]
        type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
        a.attribute(:name => attr.attrib_type.name, :namespace => attr.attrib_type.attrib_namespace.name) do |y|
          done[type_name]=1
          if attr.values.length>0
            attr.values.each do |val|
              y.value(val.value)
            end
          else
            if params[:with_default]
              attr.attrib_type.default_values.each do |val|
                y.value(val.value)
              end
            end
          end
        end
      end
    end
  end

  def write_through?
    conf = ActiveXML::Config
    conf.global_write_through && (conf::TransportMap.options_for(:project)[:write_through] != :false)
  end
  private :write_through?

  # step down through namespaces until a project is found, returns found project or nil
  def self.find_parent_for(project_name)
    name_parts = project_name.split /:/

    #project is not inside a namespace
    return nil if name_parts.length <= 1

    while name_parts.length > 1
      name_parts.pop
      if (p = DbProject.find_by_name name_parts.join(":"))
        #parent project found
        return p
      end
    end
    return nil
  end

  # convenience method for self.find_parent_for
  def find_parent
    self.class.find_parent_for self.name
  end

  def add_user( user, role_title )
    logger.debug "adding user: #{user}, #{role_title}"
    role = Role.rolecache[role_title]
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for user '#{user}' in project '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.find_by_login(user.to_s)
    end

    ProjectUserRoleRelationship.create(
        :db_project => self,
        :user => user,
        :role => role )
  end

  def add_group( group, role_title )
    logger.debug "adding group: #{group}, #{role_title}"
    role = Role.rolecache[role_title]
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for group '#{group}' in project '#{self.name}'"
    end

    unless group.kind_of? Group
      group = Group.find_by_title(group.to_s)
    end

    ProjectGroupRoleRelationship.create(
        :db_project => self,
        :group => group,
        :role => role )
  end


  # returns true if the specified user is associated with that project. possible
  # options are :login and :role
  # example:

  # proj.has_user? :login => "abauer", :role => "maintainer"
  def has_user?( opt={} )
    cond_fragments = ["db_project_id = ?"]
    cond_params = [self.id]
    join_fragments = ["purr"]

    if opt.has_key? :login
      cond_fragments << "bs_user_id = u.id"
      cond_fragments << "u.login = ?"
      cond_params << opt[:login]
      join_fragments << "users u"
    end

    if opt.has_key? :role
      cond_fragments << "role_id = r.id"
      cond_fragments << "r.title = ?"
      cond_params << opt[:role]
      join_fragments << "roles r"
    end

    return true if ProjectUserRoleRelationship.find :first,
        :select => "purr.id",
        :joins => join_fragments.join(", "),
        :conditions => [cond_fragments.join(" and "), cond_params].flatten
    return false
  end

  # proj.has_group? :title => "suse_review_team", :role => "maintainer"
  def has_group?( opt={} )
    cond_fragments = ["db_project_id = ?"]
    cond_params = [self.id]
    join_fragments = ["pgrr"]

    if opt.has_key? :name
      cond_fragments << "bs_group_id = g.id"
      cond_fragments << "g.login = ?"
      cond_params << opt[:name]
      join_fragments << "group g"
    end

    if opt.has_key? :role
      cond_fragments << "role_id = r.id"
      cond_fragments << "r.title = ?"
      cond_params << opt[:role]
      join_fragments << "roles r"
    end

    return true if ProjectGroupRoleRelationship.find :first,
        :select => "pgrr.id",
        :joins => join_fragments.join(", "),
        :conditions => [cond_fragments.join(" and "), cond_params].flatten
    return false
  end

  def each_user( opt={}, &block )
    users = User.find :all,
      :select => "bu.*, r.title AS role_name",
      :joins => "bu, project_user_role_relationships purr, roles r",
      :conditions => ["bu.id = purr.bs_user_id AND purr.db_project_id = ? AND r.id = purr.role_id", self.id]
    if( block )
      users.each do |u|
        block.call u
      end
    end
    return users
  end

  def each_group( opt={}, &block )
    groups = Group.find :all,
      :select => "bg.*, r.title AS role_name",
      :joins => "bg, project_group_role_relationships pgrr, roles r",
      :conditions => ["bg.id = pgrr.bs_group_id AND pgrr.db_project_id = ? AND r.id = pgrr.role_id", self.id]
    if( block )
      groups.each do |g|
        block.call g
      end
    end
    return groups
  end

  def to_axml
    Rails.cache.fetch('meta_project_%d' % id) do
       render_axml
    end
  end

  def render_axml
    builder = Builder::XmlMarkup.new( :indent => 2 )

    logger.debug "----------------- rendering project #{name} ------------------------"
    xml = builder.project( :name => name ) do |project|
      project.title( title )
      project.description( description )
      project.remoteurl(remoteurl) unless remoteurl.blank?
      project.remoteproject(remoteproject) unless remoteproject.blank?

      each_user do |u|
        project.person( :userid => u.login, :role => u.role_name )
      end

      each_group do |g|
        project.group( :groupid => g.title, :role => g.role_name )
      end

      self.downloads.each do |dl|
        project.download( :baseurl => dl.baseurl, :metafile => dl.metafile,
                          :mtype => dl.mtype, :arch => dl.architecture.name )
      end

      %w(build publish debuginfo useforbuild binarydownload readaccess privacy).each do |flag_name|
        flaglist = __send__(flag_name+"_flags")
        unless flaglist.empty?
          project.__send__(flag_name) do
            flaglist.each do |flag|
              project << " "*4 + flag.to_xml.to_s+"\n"
            end
          end
        end
      end

      repos = repositories.find( :all, :conditions => "ISNULL(remote_project_name)" )
      repos.each do |repo|
        project.repository( :name => repo.name ) do |r|
          repo.path_elements.each do |pe|
            if pe.link.remote_project_name.blank?
              project_name = pe.link.db_project.name
            else
              project_name = pe.link.db_project.name+":"+pe.link.remote_project_name
            end
            r.path( :project => project_name, :repository => pe.link.name )
          end
          repo.architectures.each do |arch|
            r.arch arch.name
          end
        end
      end

    end
    logger.debug "----------------- end rendering project #{name} ------------------------"

    return xml
  end

  def to_axml_id
    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.project( :name => name )
  end


  def rating( user_id=nil )
    score = 0
    self.ratings.each do |rating|
      score += rating.score
    end
    count = self.ratings.length
    score = score.to_f
    score /= count
    score = -1 if score.nan?
    score = ( score * 100 ).round.to_f / 100
    if user_rating = self.ratings.find_by_user_id( user_id )
      user_score = user_rating.score
    else
      user_score = 0
    end
    return { :score => score, :count => count, :user_score => user_score }
  end


  def activity
    # the activity of a project is measured by the average activity
    # of all its packages. this is not perfect, but ok for now.

    # get all packages including activity values
    @packages = DbPackage.find :all,
      :from => 'db_packages pac, db_projects pro',
      :conditions => "pac.db_project_id = pro.id AND pro.id = #{self.id}",
      :select => 'pro.*,' +
        "( #{DbPackage.activity_algorithm} ) AS act_tmp," +
        'IF( @activity<0, 0, @activity ) AS activity_value'
    # count packages and sum up activity values
    project = { :count => 0, :sum => 0 }
    @packages.each do |package|
      project[:count] += 1
      project[:sum] += package.activity_value.to_f
    end
    # calculate and return average activity
    return project[:sum] / project[:count]
  end


  def update_flags( opts={} )
    #needed opts: :project, :flagtype
    project = opts[:project]
    flagtype = nil
    flagclass = nil
    flag = nil

    #translate the flag types as used in the xml to model name + s
    if %w(build publish debuginfo useforbuild binarydownload readaccess privacy).include? opts[:flagtype].to_s
      flagtype = opts[:flagtype].to_s + "_flags"
    else
      raise  SaveError.new( "Error: unknown flag type '#{opts[:flagtype]}' not found." )
    end

    if project.has_element? opts[:flagtype].to_sym

      #remove old flags
      logger.debug "[DBPROJECT:FLAGS] begin transaction for updating flags"
      Flag.transaction do
        self.send(flagtype).destroy_all

        #select each build flag from xml
        project.send(opts[:flagtype]).each do |xmlflag|

          #get the selected architecture from data base
          arch = nil
          if xmlflag.has_attribute? :arch
            arch = Architecture.find_by_name(xmlflag.arch)
            raise SaveError.new( "Error: Architecture type '#{xmlarch}' not found." ) if arch.nil?
          end

          repo = xmlflag.repository if xmlflag.has_attribute? :repository
          repo ||= nil

          #instantiate new flag object
          flag = self.send(flagtype).new
          #set the flag attributes
          flag.repo = repo
          flag.status = xmlflag.data.name

          #flag position will be set through the model, but not verified

          arch.send(flagtype) << flag unless arch.nil?
          self.send(flagtype) << flag

        end
      end
      logger.debug "[DBPROJECT:FLAGS] end transaction for updating flags"

    else
      #Seems that the users has deleted all flags of the type flagtype, we will also do so.
      logger.debug "[DBPROJECT:FLAGS] Seems that the users has deleted all flags of the type #{flagtype.singularize.camelize}, we will also do so!"
      self.send(flagtype).destroy_all
    end

    #self.reload
    return true
  end

  #no build_flags and old-style-flags should be used at once
  def flag_compatibility_check( opts={} )
    project = opts[:project]
    if project.has_element? :build and
      ( project.has_element? :disable or project.has_element? :enable )
      logger.debug "[DBPROJECT:FLAG-STYLE-MISMATCH] Unable to store flags."
      raise SaveError.new("[DBPROJECT:FLAG-STYLE-MISMATCH] Unable to store flags.")
    end
  end

  #TODO this function should be removed if no longer old-style-flags in use
  def old_flag_to_build_flag( opts={} )
    project = opts[:project]

    #using a fake-project to import old-style-flags as build-flags
    fake_project = Project.new(:name => project.name)

    buildflags = REXML::Element.new("build")
    project.each_disable do |flag|
      elem = REXML::Document.new(flag.dump_xml).root
      buildflags.add_element elem
    end

    fake_project.add_node buildflags.to_s
    update_flags(:flagtype => 'build', :project => fake_project)
  end

  def complex_status(backend)
	ProjectStatusHelper.calc_status(self, backend)
  end

  private

end
