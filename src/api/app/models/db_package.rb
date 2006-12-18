class DbPackage < ActiveRecord::Base
  belongs_to :db_project
  
  has_many :package_user_role_relationships, :dependent => :destroy
  has_many :disabled_repos, :include => [:architecture, :repository], :dependent => :destroy

  class << self
    def store_axml( package )
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
  end

  def store_axml( package )
    DbPackage.transaction( self ) do
      if self.title != package.title.to_s
        self.title = package.title.to_s
        self.save!
      end

      if self.description != package.description.to_s
        self.description = package.description.to_s
        self.save!
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

            if not BsRole.rolecache.has_key? person.role
              raise RuntimeError, "illegal role name '#{person.role}'"
            end

            purr = PackageUserRoleRelationship.find_by_sql [
                "SELECT purr.*
                FROM package_user_role_relationships purr
                LEFT OUTER JOIN users ON user.id = purr.bs_user_id
                WHERE user.login = ?", person.userid]

            purr.bs_role = BsRole.rolecache[person.role]
            purr.save!
          end
          usercache.delete person.userid
        else
          begin
            PackageUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :bs_role => BsRole.rolecache[person.role],
              :db_package => self
            )
          rescue ActiveRecord::StatementInvalid => err
            if err =~ /^#23000Duplicate entry /
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
          self.disabled_repos.create(
              :repository => (repo ? db_repo : nil),
              :architecture => (arch ? Architecture.archcache[arch] : nil)
          )
        end
      end

      #delete remaining
      drcache.each do |key,obj|
        obj.destroy
      end
      #--- end update disabled repos ---#
      
      #--- write through to backend ---#
      unless ActiveXML::Config::TransportMap.options_for(:package)[:write_through] == :false
        path = "/source/#{self.db_project.name}/#{self.name}/_meta"
        Suse::Backend.put_source( path, package.dump_xml )
      end
    end
  end

  def add_user( login, role_title )
    PackageUserRoleRelationship.create(
        :db_package => self,
        :user => User.find_by_login( login ),
        :bs_role => BsRole.find_by_title( role_title ) )
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
      cond_fragments << "bs_role_id = r.id"
      cond_fragments << "r.title = ?"
      cond_params << opt[:role]
      join_fragments << "bs_roles r"
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
      :joins => "bu, package_user_role_relationships purr, bs_roles r",
      :conditions => ["bu.id = purr.bs_user_id AND purr.db_package_id = ? AND r.id = purr.bs_role_id", self.id]
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
    end
    logger.debug "----------------- end rendering package #{name} ------------------------"

    return xml
  end

  def to_axml_id
    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.package(:name => name, :project => db_project.name )
  end
end
