class Project
  class UpdateFromXmlCommand
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def run(xmlhash, force = nil)
      project.check_write_access!

      # check for raising read access permissions, which can't get ensured atm
      unless project.new_record? || project.disabled_for?('access', nil, nil)
        if FlagHelper.xml_disabled_for?(xmlhash, 'access') && !User.current.is_admin?
          raise ForbiddenError
        end
      end
      unless project.new_record? || project.disabled_for?('sourceaccess', nil, nil)
        if FlagHelper.xml_disabled_for?(xmlhash, 'sourceaccess') && !User.current.is_admin?
          raise ForbiddenError
        end
      end
      new_record = project.new_record?
      if ::Configuration.default_access_disabled == true && !new_record
        if project.disabled_for?('access', nil, nil) && !FlagHelper.xml_disabled_for?(xmlhash, 'access') && !User.current.is_admin?
          raise ForbiddenError
        end
      end

      if project.name != xmlhash['name']
        raise SaveError, "project name mismatch: #{project.name} != #{xmlhash['name']}"
      end

      project.title = xmlhash.value('title')
      project.description = xmlhash.value('description')
      project.url = xmlhash.value('url')
      project.remoteurl = xmlhash.value('remoteurl')
      project.remoteproject = xmlhash.value('remoteproject')
      project.kind = xmlhash.value('kind') if xmlhash.value('kind').present?
      project.save!

      update_linked_projects(xmlhash)
      parse_develproject(xmlhash)

      update_maintained_prjs_from_xml(xmlhash)
      project.update_relationships_from_xml(xmlhash)

      #--- update flag group ---#
      project.update_all_flags(xmlhash)
      if ::Configuration.default_access_disabled == true && new_record
        # write a default access disable flag by default in this mode for projects if not defined
        if xmlhash.elements('access').empty?
          project.flags.new(status: 'disable', flag: 'access')
        end
      end

      update_repositories(xmlhash, force)
    end

    private

    # rubocop:disable Style/GuardClause
    def update_linked_projects(xmlhash)
      position = 1
      # destroy all current linked projects
      project.linking_to.destroy_all

      # recreate linked projects from xml
      xmlhash.elements('link') do |l|
        link = Project.find_by_name(l['project'])
        if link.nil?
          if Project.find_remote_project(l['project'])
            project.linking_to.create(project: project,
                                       linked_remote_project_name: l['project'],
                                       position: position)
          else
            raise SaveError, "unable to link against project '#{l['project']}'"
          end
        else
          raise SaveError, 'unable to link against myself' if link == project
          project.linking_to.create!(project: project,
                                      linked_db_project: link,
                                      position: position)
        end
        position += 1
      end
      position
    end
    # rubocop:enable Style/GuardClause

    def parse_develproject(xmlhash)
      project.develproject = nil
      devel = xmlhash['devel']
      if devel
        prj_name = devel['project']
        if prj_name
          begin
            develprj = Project.get_by_name(prj_name)
          rescue UnknownObjectError => e
            raise UnknownObjectError, "Project with name '#{e.message}' not found"
          end
          unless develprj
            raise SaveError, "value of develproject has to be a existing project (project '#{prj_name}' does not exist)"
          end
          if develprj == project
            raise SaveError, 'Devel project can not point to itself'
          end
          project.develproject = develprj
        end
      end

      # cycle detection
      prj = project
      processed = {}

      while prj && prj.develproject
        if processed[prj.name]
          raise CycleError, "There is a cycle in devel definition at #{processed.keys.join(' -- ')}"
        end
        processed[prj.name] = 1
        prj = prj.develproject
        prj = project if prj && prj.id == project.id
      end
    end

    def update_maintained_prjs_from_xml(xmlhash)
      # First check all current maintained project relations
      olds = {}
      project.maintained_projects.each { |mp| olds[mp.project.name] = mp }

      # Set this project as the maintenance project for all maintained projects found in the XML
      xmlhash.get('maintenance').elements('maintains') do |maintains|
        pn = maintains['project']
        next if olds.delete(pn)
        maintained_project = Project.get_by_name(pn)
        MaintainedProject.create(project: maintained_project, maintenance_project: project)
      end

      project.maintained_projects.delete(olds.values)
    end

    def update_repositories(xmlhash, force)
      fill_repo_cache

      xmlhash.elements('repository') do |repo_xml_hash|
        update_repository_without_path_element(repo_xml_hash)
      end
      # Some repositories might be refered by path elements before they appear in the
      # xml tree. Thus we have 2 iterations. First one goes through all repository
      # elements, second run handles path elements.
      # This can be the case when creating multiple repositories in a project where one
      # repository uses another one, eg. importing an existing config from elsewhere.
      xmlhash.elements('repository') do |repo|
        current_repo = project.repositories.find_by_name(repo['name'])
        update_path_elements(current_repo, repo)
      end

      # delete remaining repositories in @repocache
      @repocache.each do |name, object|
        Rails.logger.debug "offending repo: #{object.inspect}"
        unless force
          # find repositories that link against this one and issue warning if found
          list = PathElement.where(repository_id: object.id)
          check_for_empty_repo_list(list, "Repository #{project.name}/#{name} cannot be deleted because following repos link against it:")
          list = ReleaseTarget.where(target_repository_id: object.id)
          check_for_empty_repo_list(
            list,
            "Repository #{project.name}/#{name} cannot be deleted because following repos define it as release target:/"
          )
        end
        Rails.logger.debug "deleting repository '#{name}'"
        project.repositories.destroy object
      end
      # save memory
      @repocache = nil
    end

    def fill_repo_cache
      @repocache = {}
      project.repositories.each do |repo|
        @repocache[repo.name] = repo if repo.remote_project_name.blank?
      end
    end

    def update_repository_without_path_element(xml_hash)
      current_repo = @repocache[xml_hash['name']]
      unless current_repo
        Rails.logger.debug "adding repository '#{xml_hash['name']}'"
        current_repo = project.repositories.new(name: xml_hash['name'])
      end
      Rails.logger.debug "modifying repository '#{xml_hash['name']}'"

      update_repository_flags(current_repo, xml_hash)
      update_release_targets(current_repo, xml_hash)
      update_hostsystem(current_repo, xml_hash)
      update_repository_architectures(current_repo, xml_hash)
      update_download_repositories(current_repo, xml_hash)

      current_repo.save!

      @repocache.delete(xml_hash['name'])
    end

    def update_path_elements(current_repo, xml_hash)
      # destroy all current pathelements
      current_repo.path_elements.destroy_all
      return unless xml_hash['path']

      # recreate pathelements from xml
      position = 1
      xml_hash.elements('path') do |path|
        link_repo = Repository.find_by_project_and_name(path['project'], path['repository'])
        if path['project'] == project.name && path['repository'] == xml_hash['name']
          raise SaveError, 'Using same repository as path element is not allowed'
        end
        unless link_repo
          raise SaveError, "unable to walk on path '#{path['project']}/#{path['repository']}'"
        end
        current_repo.path_elements.new(link: link_repo, position: position)
        position += 1
      end

      current_repo.save!
    end

    def check_for_empty_repo_list(list, error_prefix)
      return if list.empty?
      linking_repos = list.map { |x| x.repository.project.name + '/' + x.repository.name }.join "\n"
      raise SaveError, error_prefix + "\n" + linking_repos
    end

    def update_repository_flags(current_repo, xml_hash)
      current_repo.rebuild     = xml_hash['rebuild']
      current_repo.block       = xml_hash['block']
      current_repo.linkedbuild = xml_hash['linkedbuild']
    end

    def update_release_targets(current_repo, xml_hash)
      # destroy all current releasetargets
      current_repo.release_targets.destroy_all

      # recreate release targets from xml
      xml_hash.elements('releasetarget') do |release_target|
        project    = Project.find_by(name: release_target['project'])
        repository = release_target['repository']
        trigger    = release_target['trigger']

        unless project
          raise SaveError, "Project '#{release_target['project']}' does not exist."
        end

        if project.defines_remote_instance?
          raise SaveError, "Can not use remote repository as release target '#{project}/#{repository}'"
        end

        target_repo = Repository.find_by_project_and_name(project.name, repository)

        raise SaveError, "Unknown target repository '#{project}/#{repository}'" unless target_repo

        current_repo.release_targets.new(target_repository: target_repo, trigger: trigger)
      end
    end

    def update_hostsystem(current_repo, xml_hash)
      if xml_hash.key?('hostsystem')
        target_project = Project.get_by_name(xml_hash['hostsystem']['project'])
        target_repo = target_project.repositories.find_by_name(xml_hash['hostsystem']['repository'])
        if xml_hash['hostsystem']['project'] == project.name && xml_hash['hostsystem']['repository'] == xml_hash['name']
          raise SaveError, 'Using same repository as hostsystem element is not allowed'
        end
        unless target_repo
          raise SaveError, "Unknown target repository '#{xml_hash['hostsystem']['project']}/#{xml_hash['hostsystem']['repository']}'"
        end
        current_repo.hostsystem = target_repo
      else
        current_repo.hostsystem = nil
      end

      current_repo.save! if current_repo.changed?
    end

    def update_repository_architectures(current_repo, xml_hash)
      # destroy architecture references
      Rails.logger.debug "delete all repository architectures of repository '#{project.id}'"
      RepositoryArchitecture.where('repository_id = ?', current_repo.id).delete_all

      position = 1
      xml_hash.elements('arch') do |arch|
        unless Architecture.archcache.key?(arch)
          raise SaveError, "unknown architecture: '#{arch}'"
        end
        if current_repo.repository_architectures.where(architecture: Architecture.archcache[arch]).exists?
          raise SaveError, "double use of architecture: '#{arch}'"
        end
        current_repo.repository_architectures.create(architecture: Architecture.archcache[arch], position: position)
        position += 1
      end
    end

    def update_download_repositories(current_repo, xml_hash)
      current_repo.download_repositories.delete_all

      dod_repositories = xml_hash.elements('download').map do |dod|
        dod_attributes = {
          repository: current_repo,
          arch:       dod['arch'],
          url:        dod['url'],
          repotype:   dod['repotype'],
          archfilter: dod['archfilter'],
          pubkey:     dod['pubkey']
        }
        if dod['master']
          dod_attributes[:masterurl]            = dod['master']['url']
          dod_attributes[:mastersslfingerprint] = dod['master']['sslfingerprint']
        end

        repository = DownloadRepository.new(dod_attributes)
        raise SaveError, repository.errors.full_messages.to_sentence unless repository.valid?
        repository
      end
      current_repo.download_repositories.replace(dod_repositories)
    end
  end
end
