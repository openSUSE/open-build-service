class DbPackage < ActiveRecord::Base
  belongs_to :db_project

  has_many :package_user_role_relationships, :dependent => :destroy
  has_many :disabled_repos, :include => [:architecture, :repository], :dependent => :destroy
  has_many :messages, :as => :object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :object, :dependent => :destroy


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
      
      #--- update disabled repos ---#
      drcache = Hash.new
      self.disabled_repos.each do |dr|
        drcache["#{dr.repository ? dr.repository.name : nil}/_/#{dr.architecture ? dr.architecture.name : nil}"] = dr
      end

      package.each_disable do |disable|
        begin
          arch = disable.arch
        rescue NoMethodError => err
          if err.message =~ /^undefined method .arch./
            arch = nil
          else
            raise err
          end
        end

        begin
          repo = disable.repository
        rescue NoMethodError => err
          if err.message =~ /^undefined method .repository./
            repo = nil
          else
            raise err
          end
        end

        if drcache.has_key? "#{repo}/_/#{arch}"
          # tag already in database, delete from cache
          drcache.delete "#{repo}/_/#{arch}"
        else
          # new tag, add to database
          if not repo.nil?
            db_repo = self.db_project.repositories.find_by_name(repo)
            if db_repo.nil?
              logger.debug "unknown repository '#{repo}' in parent project, skipping disable"
              next
            end
          end
          begin
            self.disabled_repos.create(
              :repository => (repo ? db_repo : nil),
              :architecture => (arch ? Architecture.archcache[arch] : nil)
            )
          rescue ActiveRecord::StatementInvalid => err
            if err =~ /^Mysql::Error: Duplicate entry/
              raise RuntimeError, "duplicate disable element"
            else
              raise err
            end
          end
        end
      end

      #delete remaining
      drcache.each do |key,obj|
        obj.destroy
      end
      #--- end update disabled repos ---#

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

      each_user do |u|
        package.person( :userid => u.login, :role => u.role_name )
      end

      disreps = disabled_repos.find(:all, :include => [:repository, :architecture])
      disreps.each do |dr|
        opts = Hash.new
        opts[:repository] = dr.repository.name if dr.repository
        opts[:arch] = dr.architecture.name if dr.architecture
        package.disable( opts )
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


end
