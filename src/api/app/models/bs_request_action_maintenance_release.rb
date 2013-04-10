class BsRequestActionMaintenanceRelease < BsRequestAction

  def self.sti_name
    return :maintenance_release
  end
  
  def release_package(sourcePackage, targetProjectName, targetPackageName, revision, 
                      sourceRepository, releasetargetRepository, timestamp, request = nil)
    
    targetProject = Project.get_by_name targetProjectName

    # create package container, if missing
    tpkg = nil
    if Package.exists_by_project_and_name(targetProject.name, targetPackageName, follow_project_links: false)
      tpkg = Package.get_by_project_and_name(targetProject.name, targetPackageName, use_source: false, follow_project_links: false)
    else
      tpkg = Package.new(:name => targetPackageName, :title => sourcePackage.title, :description => sourcePackage.description)
      targetProject.packages << tpkg
      if sourcePackage.package_kinds.find_by_kind 'patchinfo'
        # publish patchinfos only
        tpkg.flags.create( :flag => 'publish', :status => "enable" )
      end
      tpkg.store
    end

    # get updateinfo id in case the source package comes from a maintenance project
    mi = MaintenanceIncident.find_by_db_project_id( sourcePackage.db_project_id ) 
    updateinfoId = nil
    if mi
      id_template = nil
      if a = mi.maintenance_db_project.find_attribute("OBS", "MaintenanceIdTemplate")
         id_template = a.values[0].value
      end
      updateinfoId = mi.getUpdateinfoId( id_template )
    end

    # detect local links
    link = nil
    begin
      link = Suse::Backend.get "/source/#{URI.escape(sourcePackage.project.name)}/#{URI.escape(sourcePackage.name)}/_link"
    rescue Suse::Backend::HTTPError
    end
    if link and ret = ActiveXML::Node.new(link.body) and (ret.project.nil? or ret.project == sourcePackage.project.name)
      ret.delete_attribute('project') # its a local link, project name not needed
      ret.set_attribute('package', ret.package.gsub(/\..*/,'') + targetPackageName.gsub(/.*\./, '.')) # adapt link target with suffix
      link_xml = ret.dump_xml
      answer = Suse::Backend.put "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}/_link?rev=repository&user=#{CGI.escape(User.current.login)}", link_xml
      md5 = Digest::MD5.hexdigest(link_xml)
      # commit with noservice parameneter
      upload_params = {
        :user => User.current.login,
        :cmd => 'commitfilelist',
        :noservice => '1',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
      }
      upload_params[:requestid] = request.id if request
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}"
      upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
      answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
      tpkg.set_package_kind_from_commit(answer.body)
    else
      # copy sources
      # backend copy of current sources as full copy
      # that means the xsrcmd5 is different, but we keep the incident project anyway.
      cp_params = {
        :cmd => "copy",
        :user => User.current.login,
        :oproject => sourcePackage.project.name,
        :opackage => sourcePackage.name,
        :comment => "Release from #{sourcePackage.project.name} / #{sourcePackage.name}",
        :expand => "1",
        :withvrev => "1",
        :noservice => "1",
      }
      cp_params[:comment] += ", setting updateinfo to #{updateinfoId}" if updateinfoId
      cp_params[:requestid] = request.id if request
      cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
      cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid, :expand, :withvrev, :noservice])
      Suse::Backend.post cp_path, nil
      tpkg.sources_changed
    end

    # copy binaries
    sourcePackage.project.repositories.each do |sourceRepo|
      sourceRepo.release_targets.each do |releasetarget|
        #FIXME2.5: filter given release and/or target repos here
        sourceRepo.architectures.each do |arch|
          if releasetarget.target_repository.project == targetProject
            cp_params = {
              :cmd => "copy",
              :oproject => sourcePackage.project.name,
              :opackage => sourcePackage.name,
              :orepository => sourceRepo.name,
              :user => User.current.login,
              :resign => "1",
            }
            cp_params[:setupdateinfoid] = updateinfoId if updateinfoId
            cp_path = "/build/#{CGI.escape(releasetarget.target_repository.project.name)}/#{URI.escape(releasetarget.target_repository.name)}/#{URI.escape(arch.name)}/#{URI.escape(targetPackageName)}"
            cp_path << Suse::Backend.build_query_from_hash(cp_params, [:cmd, :oproject, :opackage, :orepository, :setupdateinfoid, :resign])
            Suse::Backend.post cp_path, nil
          end
        end
        # remove maintenance release trigger in source
        if releasetarget.trigger == "maintenance"
          releasetarget.trigger = nil
          releasetarget.save!
          sourceRepo.project.store
        end
      end
    end

    # create or update main package linking to incident package
    unless sourcePackage.package_kinds.find_by_kind 'patchinfo'
      basePackageName = targetPackageName.gsub(/\.[^\.]*$/, '')

      # only if package does not contain a _patchinfo file
      lpkg = nil
      if Package.exists_by_project_and_name(targetProject.name, basePackageName, follow_project_links: false)
        lpkg = Package.get_by_project_and_name(targetProject.name, basePackageName, use_source: false, follow_project_links: false)
      else
        lpkg = Package.new(:name => basePackageName, :title => sourcePackage.title, :description => sourcePackage.description)
        targetProject.packages << lpkg
        lpkg.store
      end
      upload_params = {
        :user => User.current.login,
        :rev => 'repository',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
      }
      upload_params[:comment] += ", for updateinfo ID #{updateinfoId}" if updateinfoId
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}/_link"
      upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :rev])
      link = "<link package='#{targetPackageName}' cicount='copy' />\n"
      md5 = Digest::MD5.hexdigest(link)
      answer = Suse::Backend.put upload_path, link
      # commit
      upload_params[:cmd] = 'commitfilelist'
      upload_params[:noservice] = '1'
      upload_params[:requestid] = request.id if request
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}"
      upload_path << Suse::Backend.build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
      answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
      lpkg.set_package_kind_from_commit(answer.body)
    end

    # publish incident if source is read protect, but release target is not. assuming it got public now.
    if f=sourcePackage.project.flags.find_by_flag_and_status( 'access', 'disable' )
      unless targetProject.flags.find_by_flag_and_status( 'access', 'disable' )
        sourcePackage.project.flags.delete(f)
        sourcePackage.project.store({:comment => "project become public though release"})
        # patchinfos stay unpublished, it is anyway too late to test them now ...
      end
    end
  end
  
  def execute_changestate(opts)
    pkg = Package.get_by_project_and_name(self.source_project, self.source_package)
    #FIXME2.5: support limiters to specified repositories
    
    # have a unique time stamp for release
    opts[:acceptTimeStamp] ||= Time.now

    release_package(pkg, self.target_project, self.target_package, 
                    self.source_rev, nil, nil, opts[:acceptTimeStamp], self.bs_request)
    opts[:projectCommit] ||= {}
    opts[:projectCommit][self.target_project] = self.source_project
  end

  def per_request_cleanup(opts)
    # log release events once in target project
    opts[:projectCommit].each do |tprj, sprj|
      commit_params = {
        :cmd => "commit",
        :user => User.current.login,
        :requestid => self.bs_request.id,
        :rev => "latest",
        :comment => "Release from project: " + sprj
      }
      commit_path = "/source/#{URI.escape(tprj)}/_project"
      commit_path << Suse::Backend.build_query_from_hash(commit_params, [:cmd, :user, :comment, :requestid, :rev])
      Suse::Backend.post commit_path, nil
    end
    opts[:projectCommit] = {}
  end

  class LackingReleaseMaintainership < APIException
    setup "lacking_maintainership", 403
  end

  class RepositoryWithoutReleaseTarget < APIException
    setup "repository_without_releasetarget"
  end
  
  class RepositoryWithoutArchitecture < APIException
    setup "repository_without_architecture"
  end

  class ArchitectureOrderMissmatch < APIException
    setup "architecture_order_missmatch"
  end
  
  class OpenReleaseRequests < APIException
    setup "open_release_requests"
  end

  def check_permssions!
    # get sure that the releasetarget definition exists or we release without binaries
    prj = Project.get_by_name(self.source_project)
    prj.repositories.includes(:release_targets).each do |repo|
      unless repo.release_targets.size > 0
        raise RepositoryWithoutReleaseTarget.new "Release target definition is missing in #{prj.name} / #{repo.name}"
      end
      unless repo.architectures.size > 0
        raise RepositoryWithoutArchitecture.new "Repository has no architecture #{prj.name} / #{repo.name}"
      end
      repo.release_targets.each do |rt|
        unless repo.architectures.first == rt.target_repository.architectures.first
          raise ArchitectureOrderMissmatch.new "Repository and releasetarget have not the same architecture on first position: #{prj.name} / #{repo.name}"
        end
      end
    end
    
    # check for open release requests with same target, the binaries can't get merged automatically
    # either exact target package match or with same prefix (when using the incident extension)
    
    # patchinfos don't get a link, all others should not conflict with any other
    # FIXME2.4 we have a directory model
    answer = Suse::Backend.get "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}"
    xml = REXML::Document.new(answer.body.to_s)
    rel = BsRequest.where(state: [:new, :review]).joins(:bs_request_actions)
    rel = rel.where(bs_request_actions: { target_project: self.target_project })
    if xml.elements["/directory/entry/@name='_patchinfo'"]
      rel = rel.where(bs_request_actions: { target_package: self.target_package } )
    else
      tpkgprefix = self.target_package.gsub(/\.[^\.]*$/, '')
      rel = rel.where("bs_request_actions.target_package = ? or bs_request_actions.target_package like '#{tpkgprefix}.%'", self.target_package)
    end
    
    # run search
    open_ids = rel.select("bs_requests.id").all.map { |r| r.id }
    
    unless open_ids.blank?
      msg = "The following open requests have the same target #{self.target_project} / #{tpkgprefix}: " + open_ids.join(', ')
      raise OpenReleaseRequests.new msg
    end

    # creating release requests is also locking the source package, therefore we require write access there.
    spkg = Package.find_by_project_and_name self.source_project, self.source_package
    unless spkg or not User.current.can_modify_package? spkg
      raise LackingReleaseMaintainership.new "Creating a release request action requires maintainership in source package"
    end
    
  end

  def create_post_permissions_hook(opts)
    object = nil
    if opts[:per_package_locking]
      object = spkg
    else
      object = spkg.project
    end
    unless object.enabled_for?('lock', nil, nil)
      f = object.flags.find_by_flag_and_status("lock", "disable")
      object.flags.delete(f) if f # remove possible existing disable lock flag
      object.flags.create(:status => "enable", :flag => "lock")
      object.store
    end
  end
end
