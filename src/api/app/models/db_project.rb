class DbProject < ActiveRecord::Base
  has_many :project_user_role_relationships, :dependent => :destroy
  has_many :db_packages, :dependent => :destroy
  has_many :repositories, :dependent => :destroy
  has_and_belongs_to_many :tags

  class << self
    def find_by_name(name)
      find :first, :conditions => ["name = BINARY ?", name]
    end

    def store_axml( project )
      DbProject.transaction do
        if not (dbp = DbProject.find_by_name project.name)
          dbp = DbProject.new( :name => project.name.to_s )
        end
        dbp.store_axml( project )
      end
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
    DbProject.transaction( self ) do
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
          #user has already a role in this project
          pcache = usercache[person.userid]
          if pcache[:role] != person.role
            #role in xml differs from role in database, update

            if not BsRole.rolecache.has_key? person.role
              raise RuntimeError, "illegal role name '#{person.role}'"
            end

            purr = ProjectUserRoleRelationship.find_by_sql [
                "SELECT purr.*
                FROM project_user_role_relationships purr
                LEFT OUTER JOIN users ON user.id = purr.bs_user_id
                WHERE user.login = ?", person.userid]

            purr.bs_role = BsRole.rolecache[person.role]
            purr.save!
          end
          usercache.delete person.userid
        else
          begin
            ProjectUserRoleRelationship.create(
              :user => User.find_by_login(person.userid),
              :bs_role => BsRole.rolecache[person.role],
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
      
      #--- update packages ---#
      #--- end update packages ---#
      
      #--- update tags ---#
      tagcache = Hash.new
      self.tags.each do |tag|
        tagcache[tag.name] = tag
      end

      project.each_tag do |tag|
        if not tagcache.has_key? tag.to_s
          logger.debug "adding tag '#{tag.to_s}'"
          self.tags << Tag.find_or_create_by_name( tag.to_s )
          tagcache.delete tag.to_s
        end
      end

      tagcache.each do |name, object|
        logger.debug "deleting reference to tag '#{name}'"
        object.destroy
      end
      #--- end update tags ---#
      
      #--- update repositories ---#
      repocache = Hash.new
      self.repositories.each do |repo|
        repocache[repo.name] = repo
      end

      project.each_repository do |repo|
        if not repocache.has_key? repo.name
          logger.debug "adding repository '#{repo.name}'"
          current_repo = self.repositories.create( :name => repo.name )
        else
          logger.debug "modifying repository '#{repo.name}'"
          current_repo = repocache[repo.name]
        end

        #destroy all current pathelements
        current_repo.path_elements.clear

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
      end
      #--- end update repositories ---#

      #--- write through to backend ---#

      unless ActiveXML::Config::TransportMap.options_for(:project)[:write_through] == :false
        path = "/source/#{self.name}/_meta"
        Suse::Backend.put_source( path, project.dump_xml )
      end
      

    end #transaction
  end

  def add_user( login, role_title )
    logger.debug "adding user: #{login}, #{role_title}"
    ProjectUserRoleRelationship.create(
        :db_project => self,
        :bs_user => User.find_by_login( login ),
        :bs_role => BsRole.find_by_title( role_title ) )
  end


  # returns true if the specified user is associated with that project. possible
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

    return true if ProjectUserRoleRelationship.find :first,
        :select => "purr.id",
        :joins => join_fragments.join(", "),
        :conditions => [cond_fragments.join(" and "), cond_params].flatten
    return false
  end

  def each_user( opt={}, &block )
    users = User.find :all,
      :select => "bu.*, r.title AS role_name",
      :joins => "bu, project_user_role_relationships purr, bs_roles r",
      :conditions => ["bu.id = purr.bs_user_id AND purr.db_project_id = ? AND r.id = purr.bs_role_id", self.id]
    if( block )
      users.each do |u|
        block.call u
      end
    end
    return users
  end

  def to_axml
    builder = Builder::XmlMarkup.new( :indent => 2 )

    xml = builder.project( :name => name ) do |project|
      project.title( title )
      project.description( description )

      each_user do |u|
        project.person( :userid => u.login, :role => u.role_name )
      end

      #db_packages.each do |pack|
      #  project.package( :name => pack.name )
      #end

      tags.each do |tag|
        project.tag tag.name
      end

      repositories.each do |repo|
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
  end
end
