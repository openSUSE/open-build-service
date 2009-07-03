class DbPackage < ActiveRecord::Base
  class SaveError < Exception; end
  belongs_to :db_project

  belongs_to :develproject, :class_name => "DbProject" # This shall become migrated to develpackage in future

  has_many :package_user_role_relationships, :dependent => :destroy
  has_many :messages, :as => :object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :object, :dependent => :destroy

  has_many :flags
  has_many :publish_flags,  :order => :position, :extend => FlagExtension
  has_many :build_flags,  :order => :position, :extend => FlagExtension
  has_many :debuginfo_flags,  :order => :position, :extend => FlagExtension
  has_many :useforbuild_flags,  :order => :position, :extend => FlagExtension
  has_many :binarydownload_flags,  :order => :position, :extend => FlagExtension

  has_one :meta_cache, :as => :cachable, :dependent => :delete
  has_one :develpackage, :class_name => "DbPackage", :foreign_key => 'develpackage_id'

  has_many :attributes, :dependent => :destroy

  # disable automatic timestamp updates (updated_at and created_at)
  # but only for this class, not(!) for all ActiveRecord::Base instances
  def record_timestamps
    false
  end

  class << self
    def store_axml( package )
      dbp = nil
      DbPackage.transaction do
        project_name = package.parent_project_name
        if not( dbp = DbPackage.find_by_project_and_name(project_name, package.name) )
          pro = DbProject.find_by_name project_name
          if pro.nil?
            raise SaveError, "unknown project '#{project_name}'"
          end
          dbp = DbPackage.new( :name => package.name.to_s )
          pro.db_packages << dbp
        end
        dbp.store_axml( package )
      end
      return dbp
    end

    def find_by_project_and_name( project, package )
      sql =<<-END_SQL
      SELECT pack.*
      FROM db_packages pack
      LEFT OUTER JOIN db_projects pro ON pack.db_project_id = pro.id
      WHERE pro.name = BINARY ? AND pack.name = BINARY ?
      END_SQL

      result = DbPackage.find_by_sql [sql, project.to_s, package.to_s]
      result[0]
    end

    def activity_algorithm
      # this is the algorithm (sql) we use for calculating activity of packages
      '@activity:=( ' +
        'pac.activity_index - ' +
        'POWER( TIME_TO_SEC( TIMEDIFF( NOW(), pac.updated_at ))/86400, 1.55 ) /10 ' +
      ')'
    end
  end

  def store_axml( package )
    DbPackage.transaction do
      self.title = package.title.to_s
      self.description = package.description.to_s
      self.bcntsynctag = package.bcntsynctag.to_s if package.has_element? :bcntsynctag

      #--- devel project ---#
      self.develproject = nil      # old column, get removed now always and migrated to new develpackage
                                   # might get reused later for defining devel projects in project meta
      self.develpackage = nil
      if package.has_element? :devel
        prj_name = package.project.to_s
        pkg_name = package.name.to_s
        if package.devel.has_attribute? 'project'
          prj_name = package.devel.project.to_s
        end
        if package.devel.has_attribute? 'package'
          pkg_name = package.devel.package.to_s
        end
        unless develprj = DbProject.find_by_name(prj_name)
          raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
        end
        unless develpkg = develprj.db_packages.find_by_name(pkg_name)
          raise SaveError, "value of develpackage has to be a existing package (package '#{pkg_name}' does not exist)"
        end
        self.develpackage = develpkg
      end
      #--- end devel project ---#

      #--- update users ---#
      usercache = Hash.new
      self.package_user_role_relationships.each do |purr|
        h = usercache[purr.user.login] ||= Hash.new
        h[purr.role.title] = purr
      end

      package.each_person do |person|
        if usercache.has_key? person.userid
          #user has already a role in this package
          pcache = usercache[person.userid]
          if pcache.has_key? person.role
            #role already defined, only remove from cache
            pcache[person.role] = :keep
          else
            #new role
            if not Role.rolecache.has_key? person.role
              raise SaveError, "illegal role name '#{person.role}'"
            end
            PackageUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :role => Role.rolecache[person.role],
              :db_package => self
            )
          end
        else
          begin
            PackageUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :role => Role.rolecache[person.role],
              :db_package => self
            )
          rescue ActiveRecord::StatementInvalid => err
            if /^Mysql::Error: Duplicate entry/.match(err)
              logger.debug "user '#{person.userid}' already has the role '#{person.role}' in package '#{self.name}'"
            else
              raise err
            end
          end
        end
      end

      #delete all roles that weren't found in uploaded xml
      usercache.each do |user, roles|
        roles.each do |role, object|
          next if object == :keep
          object.destroy
        end
      end

      #--- end update users ---#


      #---begin enable / disable flags ---#
      flag_compatibility_check( :package => package )
      %w(build publish debuginfo useforbuild binarydownload).each do |flagtype|
        update_flags( :package => package, :flagtype => flagtype )
      end

      #add old-style-flags as build-flags
      old_flag_to_build_flag( :package => package ) if package.has_element? :disable
      #--- end enable / disable flags ---#


      #--- update url ---#
      if package.has_element? :url
        if self.url != package.url.to_s
          self.url = package.url.to_s
        end
      else
        self.url = nil
      end
      #--- end update url ---#

      # update timestamp and save
      self.update_timestamp
      self.save!

      # update cache
      build_meta_cache if meta_cache.nil?
      meta_cache.content = render_axml
      meta_cache.save!

      #--- write through to backend ---#
      if write_through?
        path = "/source/#{self.db_project.name}/#{self.name}/_meta"
        Suse::Backend.put_source( path, package.dump_xml )
      end
    end
  end

  def write_through?
    conf = ActiveXML::Config
    conf.global_write_through && (conf::TransportMap.options_for(:package)[:write_through] != :false)
  end

  def add_user( user, role_title )
    role = Role.rolecache[role_title]
    if role.global
      #only nonglobal roles may be set in a project
      raise SaveError, "tried to set global role '#{role_title}' for user '#{user}' in package '#{self.name}'"
    end

    unless user.kind_of? User
      user = User.find_by_login(user.to_s)
    end

    PackageUserRoleRelationship.create(
        :db_package => self,
        :user => user,
        :role => role )
  end

  # returns true if the specified user is associated with that package. possible
  # options are :login and :role
  # example:
  #
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

    return true if PackageUserRoleRelationship.find :first,
        :select => "purr.id",
        :joins => join_fragments.join(", "),
        :conditions => [cond_fragments.join(" and "), cond_params].flatten
    return false
  end

  def each_user( opt={}, &block )
    users = User.find :all,
      :select => "bu.*, r.title AS role_name",
      :joins => "bu, package_user_role_relationships purr, roles r",
      :conditions => ["bu.id = purr.bs_user_id AND purr.db_package_id = ? AND r.id = purr.role_id", self.id]
    if( block )
      users.each do |u|
        block.call u
      end
    end
    return users
  end

  def to_axml
    create_meta_cache(:content => render_axml) if meta_cache.nil?
    return meta_cache.content
  end

  def render_axml
    builder = Builder::XmlMarkup.new( :indent => 2 )

    logger.debug "----------------- rendering package #{name} ------------------------"
    xml = builder.package( :name => name, :project => db_project.name ) do |package|
      package.title( title )
      package.description( description )
      
      if develpackage
        package.devel( :project => develpackage.db_project.name, :package => develpackage.name )
      elsif develproject
        package.devel( :project => develproject.name )
      end

      each_user do |u|
        package.person( :userid => u.login, :role => u.role_name )
      end

      %w(build publish debuginfo useforbuild binarydownload).each do |flag_name|
        flaglist = __send__(flag_name+"_flags")
        unless flaglist.empty?
          package.__send__(flag_name) do
            flaglist.each do |flag|
              package << " "*4 + flag.to_xml.to_s+"\n"
            end
          end
        end
      end

      package.url( url ) if url
      package.bcntsynctag( bcntsynctag ) if bcntsynctag

    end
    logger.debug "----------------- end rendering package #{name} ------------------------"

    return xml
  end

  def to_axml_id
    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.package( :name => name, :project => db_project.name )
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
    package = DbPackage.find :first,
      :from => 'db_packages pac, db_projects pro',
      :conditions => "pac.db_project_id = pro.id AND pac.id = #{self.id}",
      :select => "pac.*, pro.name AS project_name, " +
        "( #{DbPackage.activity_algorithm} ) AS act_tmp," +
        "IF( @activity<0, 0, @activity ) AS activity_value"
    return package.activity_value.to_f
  end

  def update_timestamp
    # the value we add to the activity, when the object gets updated
    activity_addon = 10
    activity_addon += Math.log( self.update_counter ) if update_counter > 0
    new_activity = activity + activity_addon
    new_activity = 100 if new_activity > 100

    self.activity_index = new_activity
    self.created_at ||= Time.now
    self.updated_at = Time.now
    self.update_counter += 1
  end

  def update_flags( opts={} )
    #needed opts: :package, :flagtype
    package = opts[:package]
    flagtype = nil
    flagclass = nil
    flag = nil

    #translates the flag types as used in the xml to model name + s
    if %w(build publish debuginfo useforbuild binarydownload).include? opts[:flagtype].to_s
      flagtype = opts[:flagtype].to_s + "_flags"
    else
      raise  SaveError.new( "Error: unknown flag type '#{opts[:flagtype]}' not found." )
    end

    if package.has_element? opts[:flagtype].to_sym

      #remove old flags
      logger.debug "[DBPACKAGE:FLAGS] begin transaction for updating flags"
      Flag.transaction do
        self.send(flagtype).destroy_all

        #select each build flag from xml
        package.send(opts[:flagtype]).each do |xmlflag|

          #get the selected architecture from data base
          arch = nil
          if xmlflag.has_attribute? :arch
            arch = Architecture.find_by_name(xmlflag.arch)
            raise SaveError.new( "Error: Architecture type '#{xmlflag.arch}' not found." ) if arch.nil?
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
      logger.debug "[DBPACKAGE:FLAGS] end transaction for updating flags"

    else
      #Seems that the users has deleted all flags of the type flagtype, we will also do so.
      logger.debug "[DBPACKAGE:FLAGS] Seems that the users has deleted all flags of the type #{flagtype.singularize.camelize}, we will also do so!"
      self.send(flagtype).destroy_all
    end

    #self.reload
    return true
  end

  #TODO this function should be removed if no longer old-style-flags in use
  #no build_flags and old-style-flags should be used at once
  def flag_compatibility_check( opts={} )
    package = opts[:package]
    if package.has_element? :build and
      ( package.has_element? :disable or package.has_element? :enable )
      logger.debug "[DBPACKAGE:FLAG-STYLE-MISMATCH] Unable to store flags."
      raise SaveError.new("[DBPACKAGE:FLAG-STYLE-MISMATCH] Unable to store flags.")
    end
  end

  #TODO this function should be removed if no longer old-style-flags in use
  def old_flag_to_build_flag( opts={} )
    package = opts[:package]

    #using a fake-project to import old-style-flags as build-flags
    fake_package = Package.new(:name => package.name)

    buildflags = REXML::Element.new("build")
    package.each_disable do |flag|
      elem = REXML::Element.new(flag.data)
      buildflags.add_element(elem)
    end

    fake_package.add_element(buildflags)
    #return fake_package
    update_flags(:flagtype => 'build', :package => fake_package)
  end
end
