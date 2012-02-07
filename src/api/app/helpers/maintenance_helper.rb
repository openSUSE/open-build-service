module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil, noaccess = false )
    mi = nil
    tprj = nil
    DbProject.transaction do
      mi = MaintenanceIncident.new( :maintenance_db_project_id => maintenanceProject.id ) 
      tprj = DbProject.new :name => mi.project_name
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title.dup if baseProject.title
        tprj.description = baseProject.description.dup if baseProject.description
        tprj.save
        baseProject.flags.each do |f|
          tprj.flags.create(:status => f.status, :flag => f.flag)
        end
      else
        # mbranch call is enabling selected packages
        tprj.save
        tprj.flags.create( :position => 1, :flag => 'build', :status => "disable" )
      end
      # publish is disabled, just patchinfos get enabled
      tprj.flags.create( :flag => 'publish', :status => "disable" )
      if noaccess
        tprj.flags.create( :flag => 'access', :status => "disable" )
      end
      # take over roles from maintenance project
      maintenanceProject.project_user_role_relationships.each do |r| 
        ProjectUserRoleRelationship.create(
              :user => r.user,
              :role => r.role,
              :db_project => tprj
            )
      end
      maintenanceProject.project_group_role_relationships.each do |r| 
        ProjectGroupRoleRelationship.create(
              :group => r.group,
              :role => r.role,
              :db_project => tprj
            )
      end
      # set default bugowner if missing
      bugowner = Role.get_by_title("bugowner")
      unless tprj.project_user_role_relationships.find :first, :conditions => ["role_id = ?", bugowner], :include => :role
        tprj.add_user( @http_user, bugowner )
      end
      # and write it
      tprj.set_project_type "maintenance_incident"
      tprj.store
      mi.db_project_id = tprj.id
      mi.save!
    end
    return mi
  end

  def merge_into_maintenance_incident(incidentProject, base, request = nil)

    # copy all or selected packages and project source files from base project
    # we don't branch from it to keep the link target.
    packages = nil
    if base.class == DbProject
      packages = base.db_packages
    else
      packages = [base]
    end

    packages.each do |pkg|
      new = DbPackage.new(:name => pkg.name, :title => pkg.title, :description => pkg.description)
      incidentProject.db_packages << new
      pkg.flags.each do |f|
        new.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo)
      end
      new.store
      # add missing repos
      pkg.db_project.repositories.each do |r|
        # skip existing ones
        next if incidentProject.repositories.find_by_name r.name

        trepo = incidentProject.repositories.create :name => r.name
        trepo.architectures = r.architectures
        r.path_elements.each do |pe|
          trepo.path_elements.create(:link => pe.link, :position => pe.position)
        end
        r.release_targets.each do |rr|
          trepo.release_targets.create(:target_repository => rr.target_repository, :trigger => "maintenance")
        end
      end

      # backend copy of current sources
      cp_params = {
        :cmd => "copy",
        :user => @http_user.login,
        :oproject => pkg.db_project.name,
        :opackage => pkg.name,
        :comment => "Maintenance copy from project " + pkg.db_project.name
      }
      cp_params[:requestid] = request.id if request
      cp_path = "/source/#{CGI.escape(incidentProject.name)}/#{CGI.escape(pkg.name)}"
      cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid])
      Suse::Backend.post cp_path, nil
      new.sources_changed
    end

    incidentProject.save!
    incidentProject.store
  end

  def release_package(sourcePackage, targetProjectName, targetPackageName, revision, sourceRepository, releasetargetRepository, timestamp, request = nil)

    targetProject = DbProject.get_by_name targetProjectName

    # create package container, if missing
    tpkg = nil
    if DbPackage.exists_by_project_and_name(targetProject.name, targetPackageName, follow_project_links=false)
      tpkg = DbPackage.get_by_project_and_name(targetProject.name, targetPackageName, follow_project_links=false)
    else
      tpkg = DbPackage.new(:name => targetPackageName, :title => sourcePackage.title, :description => sourcePackage.description)
      targetProject.db_packages << tpkg
      if sourcePackage.db_package_kinds.find_by_kind 'patchinfo'
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
      link = Suse::Backend.get "/source/#{URI.escape(sourcePackage.db_project.name)}/#{URI.escape(sourcePackage.name)}/_link"
    rescue Suse::Backend::HTTPError
    end
    if link and ret = ActiveXML::XMLNode.new(link.body) and (ret.project.nil? or ret.project == sourcePackage.db_project.name)
      ret.delete_attribute('project') # its a local link, project name not needed
      ret.set_attribute('package', ret.package.gsub(/\..*/,'') + targetPackageName.gsub(/.*\./, '.')) # adapt link target with suffix
      link_xml = ret.dump_xml
      answer = Suse::Backend.put "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}/_link?rev=repository&user=#{CGI.escape(@http_user.login)}", link_xml
      md5 = Digest::MD5.hexdigest(link_xml)
      # commit with noservice parameneter
      upload_params = {
        :user => @http_user.login,
        :cmd => 'commitfilelist',
        :noservice => '1',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
      }
      upload_params[:requestid] = request.id if request
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(targetPackageName)}"
      upload_path << build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
      answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
      tpkg.set_package_kind_from_commit(answer.body)
    else
      # copy sources
      # backend copy of current sources as full copy
      # that means the xsrcmd5 is different, but we keep the incident project anyway.
      cp_params = {
        :cmd => "copy",
        :user => @http_user.login,
        :oproject => sourcePackage.db_project.name,
        :opackage => sourcePackage.name,
        :comment => "Release from #{sourcePackage.db_project.name} / #{sourcePackage.name}",
        :expand => "1",
        :withvrev => "1",
        :noservice => "1",
      }
      cp_params[:comment] += ", setting updateinfo to #{updateinfoId}" if updateinfoId
      cp_params[:requestid] = request.id if request
      cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
      cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid, :expand, :withvrev, :noservice])
      Suse::Backend.post cp_path, nil
      tpkg.sources_changed
    end

    # copy binaries
    sourcePackage.db_project.repositories.each do |sourceRepo|
      sourceRepo.release_targets.each do |releasetarget|
        #FIXME2.5: filter given release and/or target repos here
        sourceRepo.architectures.each do |arch|
          if releasetarget.target_repository.db_project == targetProject
            cp_params = {
              :cmd => "copy",
              :oproject => sourcePackage.db_project.name,
              :opackage => sourcePackage.name,
              :orepository => sourceRepo.name,
              :user => @http_user.login,
              :resign => "1",
            }
            cp_params[:setupdateinfoid] = updateinfoId if updateinfoId
            cp_path = "/build/#{CGI.escape(releasetarget.target_repository.db_project.name)}/#{URI.escape(releasetarget.target_repository.name)}/#{URI.escape(arch.name)}/#{URI.escape(targetPackageName)}"
            cp_path << build_query_from_hash(cp_params, [:cmd, :oproject, :opackage, :orepository, :setupdateinfoid, :resign])
            Suse::Backend.post cp_path, nil
          end
        end
        # remove maintenance release trigger in source
        if releasetarget.trigger == "maintenance"
          releasetarget.trigger = "manual"
          releasetarget.save!
          sourceRepo.db_project.store
        end
      end
    end

    # create or update main package linking to incident package
    unless sourcePackage.db_package_kinds.find_by_kind 'patchinfo'
      basePackageName = targetPackageName.gsub(/\.[^\.]*$/, '')

      # only if package does not contain a _patchinfo file
      lpkg = nil
      if DbPackage.exists_by_project_and_name(targetProject.name, basePackageName, follow_project_links=false)
        lpkg = DbPackage.get_by_project_and_name(targetProject.name, basePackageName, follow_project_links=false)
      else
        lpkg = DbPackage.new(:name => basePackageName, :title => sourcePackage.title, :description => sourcePackage.description)
        targetProject.db_packages << lpkg
        lpkg.store
      end
      upload_params = {
        :user => @http_user.login,
        :rev => 'repository',
        :comment => "Set link to #{targetPackageName} via maintenance_release request",
      }
      upload_params[:comment] += ", for updateinfo ID #{updateinfoId}" if updateinfoId
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}/_link"
      upload_path << build_query_from_hash(upload_params, [:user, :rev])
      link = "<link package='#{targetPackageName}' cicount='copy' />\n"
      md5 = Digest::MD5.hexdigest(link)
      answer = Suse::Backend.put upload_path, link
      # commit
      upload_params[:cmd] = 'commitfilelist'
      upload_params[:noservice] = '1'
      upload_params[:requestid] = request.id if request
      upload_path = "/source/#{URI.escape(targetProject.name)}/#{URI.escape(basePackageName)}"
      upload_path << build_query_from_hash(upload_params, [:user, :comment, :cmd, :noservice, :requestid])
      answer = Suse::Backend.post upload_path, "<directory> <entry name=\"_link\" md5=\"#{md5}\" /> </directory>"
      lpkg.set_package_kind_from_commit(answer.body)
    end
  end
end
