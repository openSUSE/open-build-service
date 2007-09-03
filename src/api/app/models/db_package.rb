class DbPackage < ActiveRecord::Base
  belongs_to :db_project

  has_many :package_user_role_relationships, :dependent => :destroy
  has_many :messages, :as => :object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :object, :dependent => :destroy

  has_many :flags
  has_many :publish_flags,  :order => :position
  has_many :build_flags,  :order => :position
  has_many :debug_flags,  :order => :position
  has_many :useforbuild_flags,  :order => :position

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
            raise RuntimeError, "unknown project '#{project_name}'"
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
      if self.title != package.title.to_s
        self.title = package.title.to_s
        #self.save!
      end

      if self.description != package.description.to_s
        self.description = package.description.to_s
        #self.save!
      end

      #--- update users ---#
      usercache = Hash.new
      self.each_user do |user|
        usercache[user.login] = {:role => user.role_name, :dbid => user.id}
      end

      package.each_person do |person|
        if usercache.has_key?(person.userid)
          #user has already a role in this package
          pcache = usercache[person.userid]
          if pcache[:role] != person.role
            #role in xml differs from role in database, update

            if not Role.rolecache.has_key? person.role
              raise RuntimeError, "illegal role name '#{person.role}'"
            end

            purr = PackageUserRoleRelationship.find_by_sql [
                "SELECT purr.*
                FROM package_user_role_relationships purr
                LEFT OUTER JOIN users ON user.id = purr.bs_user_id
                WHERE user.login = ?", person.userid]

            purr.role = Role.rolecache[person.role]
            purr.save!
          end
          usercache.delete person.userid
        else
          begin
            PackageUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :role => Role.rolecache[person.role],
              :db_package => self
            )
          rescue ActiveRecord::StatementInvalid => err
            if err =~ /^Mysql::Error: Duplicate entry/
              logger.debug "user '#{person.userid}' already has the role '#{person.role}' in package '#{self.name}'"
            else
              raise err
            end
          end
        end
      end

      user_ids_to_delete = usercache.map {|login, hash| hash[:dbid]}.join ", "
      unless user_ids_to_delete.empty?
        PackageUserRoleRelationship.destroy_all ["db_package_id = ? AND bs_user_id IN (#{user_ids_to_delete})", self.id]
      end
      #--- end update users ---#


      #---begin enable / disable flags ---#
      flag_compatibility_check( :package => package )
      ['build', 'publish', 'debug', 'useforbuild'].each do |flagtype|
        update_flags( :package => package, :flagtype => flagtype )
      end

      #add old-style-flags as build-flags
      old_flag_to_build_flag( :package => package ) if package.has_element? :disable
      #--- end enable / disable flags ---#


      #--- update url ---#
      if package.has_element? :url
        if self.url != package.url.to_s
          self.url = package.url.to_s
          #self.save!
        end
      else
        self.url = nil
        #self.save!
      end
      #--- end update url ---#

      # update timestamp and save
      self.update_timestamp
      self.save!

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


  def add_user( login, role_title )
    role = Role.rolecache[role_title]
    if role.global
      #only nonglobal roles may be set in a project
      raise RuntimeError, "tried to set global role '#{role_title}' for user '#{login}' in package '#{self.name}'"
    end

    PackageUserRoleRelationship.create(
        :db_package => self,
        :user => User.find_by_login( login ),
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
    builder = Builder::XmlMarkup.new( :indent => 2 )

    logger.debug "----------------- rendering package #{name} ------------------------"
    xml = builder.package( :name => name, :project => db_project.name ) do |package|
      package.title( title )
      package.description( description )

    #TODO put the flag stuff in a loop
    unless self.build_flags.empty?
      package.build do
        self.build_flags.each do |build_flag|
#          project.__send__(build_flag.status.to_s,
#                            :arch => build_flag.architecture.name.to_s,
#                            :repo => build_flag.repo.to_s
#                            )
          package << build_flag.to_xml.to_s + "\n"
        end
      end
    end

    unless self.publish_flags.empty?
      package.publish do
        self.publish_flags.each do |publish_flag|
#          project.__send__(publish_flag.status.to_s,
#                            :arch => publish_flag.architecture.name.to_s,
#                            :repo => publish_flag.repo.to_s
#                            )
          package << publish_flag.to_xml.to_s + "\n"
        end
      end
    end

    unless self.debug_flags.empty?
      package.debug do
        self.debug_flags.each do |debug_flag|
#          package.__send__(debug_flag.status.to_s,
#                            :arch => debug_flag.architecture.name.to_s,
#                            :repo => debug_flag.repo.to_s
#                            )
          package << debug_flag.to_xml.to_s + "\n"
        end
      end
    end

    unless self.useforbuild_flags.empty?
      package.useforbuild do
        self.useforbuild_flags.each do |useforbuild_flags|
#          package.__send__(useforbuild_flags.status.to_s,
#                            :arch => useforbuild_flags.architecture.name.to_s,
#                            :repo => useforbuild_flags.repo.to_s
#                            )
          package << useforbuild_flags.to_xml.to_s + "\n"
        end
      end
    end

    each_user do |u|
      package.person( :userid => u.login, :role => u.role_name )
    end


    package.url( url ) if url

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
    case opts[:flagtype].to_sym
      when :build
        flagtype = "build_flags"
      when :publish
        flagtype = "publish_flags"
      when :debug
        flagtype = "debug_flags"
      when :useforbuild
        flagtype = "useforbuild_flags"
      else
        raise  RuntimeError.new( "Error: unknown flag type '#{opts[:flagtype]}' not found." )
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
            raise RuntimeError.new( "Error: Architecture type '#{xmlflag.arch}' not found." ) if arch.nil?
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
      raise RuntimeError.new("[DBPACKAGE:FLAG-STYLE-MISMATCH] Unable to store flags.")
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
