class DbProject < ActiveRecord::Base

  has_many :project_user_role_relationships, :dependent => :destroy
  has_many :db_packages, :dependent => :destroy
  has_many :repositories, :dependent => :destroy
  has_many :messages, :as => :object, :dependent => :destroy

  has_many :taggings, :as => :taggable, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :download_stats
  has_many :ratings, :as => :object, :dependent => :destroy

  has_many :project_flag_groups
  has_many :project_flags, :through => :project_flag_groups

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
  end

  def store_axml( project )
    DbProject.transaction do
      logger.debug "### name comparison: self.name -> #{self.name}, project_name -> #{project.name.to_s}"
      if self.name != project.name.to_s
        raise RuntimeError, "project name mismatch: #{self.name} != #{project.name}"
      end

      if self.title != project.title.to_s
        self.title = project.title.to_s
        self.save!
      end

      if self.description != project.description.to_s
        self.description = project.description.to_s
        self.save!
      end

      #--- update users ---#
      usercache = Hash.new
      self.each_user do |user|
        usercache[user.login] = {:role => user.role_name, :dbid => user.id}
      end

      project.each_person do |person|
        if usercache.has_key?(person.userid)
          # user has already a role in this project
          pcache = usercache[person.userid]
          if pcache[:role] != person.role
            #role in xml differs from role in database, update

            if not Role.rolecache.has_key? person.role
              raise RuntimeError, "illegal role name '#{person.role}'"
            end

            purr = ProjectUserRoleRelationship.find_by_sql [
                "SELECT purr.*
                FROM project_user_role_relationships purr
                LEFT OUTER JOIN users ON user.id = purr.bs_user_id
                WHERE user.login = ?", person.userid]

            purr.role = Role.rolecache[person.role]
            purr.save!
          end
          usercache.delete person.userid
        else
          begin
            ProjectUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :role => Role.rolecache[person.role],
              :db_project => self
            )
          rescue ActiveRecord::StatementInvalid => err
            logger.debug "ping"
            if err =~ /^#23000Duplicate entry /
              logger.debug "user '#{person.userid}' already has the role '#{person.role}' in project '#{self.name}'"
            else
              raise err
            end
          end
        end
      end

      user_ids_to_delete = usercache.map {|login, hash| hash[:dbid]}.join ", "
      unless user_ids_to_delete.empty?
        ProjectUserRoleRelationship.destroy_all ["db_project_id = ? AND bs_user_id IN (#{user_ids_to_delete})", self.id]
      end
      #--- end update users ---#

      #--- update flag group ---#
      # destroy all flags and flag groups first
      self.project_flags.destroy_all
      self.project_flag_groups.destroy_all

      # and recreate the flag groups and flags again
      FlagGroupType.find(:all).each do |gt|
	if project.has_element?(gt.title)
          logger.debug "adding flag group '#{gt.title}'"
          current_fg = self.project_flag_groups.create( :flag_group_type_id => gt.id )
          self.updated_at = Time.now

          FlagType.find(:all).each do |ft|
            if project.send("#{gt.title}").has_element?(ft.title)
              logger.debug "adding flag '#{ft.title}'"
              begin
                ProjectFlag.create(
                  :project_flag_group_id => gt.id,
                  :flag_type_id => ft.id
                )
              rescue ActiveRecord::StatementInvalid => err
                logger.debug "error handling flag"
              end
            end
          end
        end
      end
      #--- end flag group ---#

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
        current_repo.path_elements.sort {|a,b| b.id <=> a.id}.each do |pe|
          pe.destroy
        end

        #recreate pathelements from xml
        repo.each_path do |path|
          link_repo = Repository.find_by_project_and_repo_name( path.project, path.repository )
          if link_repo.nil?
            raise RuntimeError, "unable to walk on path '#{path.project}/#{path.repository}'"
          end
          current_repo.path_elements.create :link => link_repo
        end

        #destroy architecture references
        current_repo.architectures.clear

        repo.each_arch do |arch|
          unless Architecture.archcache.has_key? arch.to_s
            raise RuntimeError, "unknown architecture: '#{arch}'"
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
          linking_repos = list.map {|x| x.repository.db_project.name+"/"+x.repository.name}.join "\n"
          raise RuntimeError, "Repository #{self.name}/#{name} cannot be deleted because following repos link against it:\n"+linking_repos
        end
        logger.debug "deleting repository '#{name}'"
        object.destroy
        self.updated_at = Time.now
      end
      #--- end update repositories ---#

      #--- write through to backend ---#

      # update 'updated_at' timestamp
      self.save! if project.has_attribute? 'updated' and self.updated_at.xmlschema != project.updated

      if write_through?
        path = "/source/#{self.name}/_meta"
        Suse::Backend.put_source( path, project.dump_xml )
      end
    end #transaction
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

  def add_user( login, role_title )
    logger.debug "adding user: #{login}, #{role_title}"
    role = Role.rolecache[role_title]
    if role.global
      #only nonglobal roles may be set in a project
      raise RuntimeError, "tried to set global role '#{role_title}' for user '#{login}' in project '#{self.name}'"
    end

    ProjectUserRoleRelationship.create(
        :db_project => self,
        :user => User.find_by_login( login ),
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

  def to_axml
    builder = Builder::XmlMarkup.new( :indent => 2 )

    logger.debug "----------------- rendering project #{name} ------------------------"
    xml = builder.project( :name => name ) do |project|
      project.title( title )
      project.description( description )

      each_user do |u|
        project.person( :userid => u.login, :role => u.role_name )
      end

      FlagGroupType.find(:all).each do |gt|
        flaglist = ProjectFlagGroup.find_by_sql [
          "SELECT ft.title AS flagswitch from project_flag_groups fg 
                  LEFT JOIN flag_group_types fgt ON fg.flag_group_type_id=fgt.id 
                  LEFT JOIN project_flags f ON f.project_flag_group_id=fgt.id 
                  LEFT JOIN flag_types ft ON f.flag_type_id=ft.id 
           WHERE fg.db_project_id=? AND fgt.title=? ;", self.id, gt.title ]

        if not flaglist.empty?
          project.__send__("#{gt.title}") do |u|
            flaglist.each do |fs|
              project.__send__("#{fs.flagswitch}")
            end
          end
        end
      end

      repos = repositories.find( :all, :include => [:path_elements, :architectures] )
      repos.each do |repo|
        project.repository( :name => repo.name ) do |r|
          repo.path_elements.each do |pe|
            r.path( :project => pe.link.db_project.name, :repository => pe.link.name )
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


end
