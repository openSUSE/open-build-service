module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil, noaccess = false )
    mi = MaintenanceIncident.new( :maintenance_db_project_id => maintenanceProject.id ) 

    tprj = nil
    DbProject.transaction do
      tprj = DbProject.new :name => mi.project_name
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title.dup if baseProject.title
        tprj.description = baseProject.description.dup if baseProject.description
        tprj.save
        baseProject.flags.each do |f|
          tprj.flags.create(:status => f.status, :flag => f.flag)
        end
        baseProject.repositories.each do |r|
          trepo = tprj.repositories.create :name => r.name
          trepo.architectures = r.architectures
          r.path_elements.each do |pe|
            trepo.path_elements.create(:link => pe.link, :position => pe.position)
          end
          r.release_targets.each do |rr|
            trepo.release_targets.create(:target_repository => rr.target_repository, :trigger => "maintenance")
          end
        end
      else
        # mbranch call is enabling selected packages
        tprj.save
        tprj.flags.create( :position => 1, :flag => 'build', :status => "disable" )
      end
      if noaccess
        tprj.flags.create( :flag => 'access', :status => "disable" )
        tprj.flags.create( :flag => 'publish', :status => "disable" )
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

    # copy all packages and project source files from base project
    # we don't branch from it to keep the link target.
    if baseProject
      baseProject.db_packages.each do |pkg|
        new = DbPackage.new(:name => pkg.name, :title => pkg.title, :description => pkg.description)
        tprj.db_packages << new
        pkg.flags.each do |f|
          new.flags.create(:status => f.status, :flag => f.flag, :architecture => f.architecture, :repo => f.repo)
        end
        new.store

        # backend copy of current sources
        cp_params = {
          :cmd => "copy",
          :user => @http_user.login,
          :oproject => baseProject.name,
          :opackage => pkg.name,
          :comment => "Maintenance copy from project " + baseProject.name
        }
        cp_params[:requestid] = request.id if request
        cp_path = "/source/#{CGI.escape(tprj.name)}/#{CGI.escape(pkg.name)}"
        cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid])
        Suse::Backend.post cp_path, nil
      end
    end

    return mi
  end

  def release_package(sourcePackage, targetProjectName, targetPackageName, revision, sourceRepository, releasetargetRepository, timestamp, request = nil)

    targetProject = DbProject.get_by_name targetProjectName

    # create package container, if missing
    unless DbPackage.exists_by_project_and_name(targetProject.name, targetPackageName, follow_project_links=false)
      new = DbPackage.new(:name => targetPackageName, :title => sourcePackage.title, :description => sourcePackage.description)
      targetProject.db_packages << new
      new.store
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
    }
    cp_params[:comment] = "Release updateinfo #{updateinfoId}" if updateinfoId
    cp_params[:requestid] = request.id if request
    cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
    cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid, :expand, :withvrev])
    Suse::Backend.post cp_path, nil

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
            cp_path = "/build/#{CGI.escape(releasetarget.target_repository.db_project.name)}/#{CGI.escape(releasetarget.target_repository.name)}/#{CGI.escape(arch.name)}/#{CGI.escape(targetPackageName)}"
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
    basePackageName = targetPackageName.gsub(/\..*/, '')
    answer = Suse::Backend.get "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
    xml = REXML::Document.new(answer.body.to_s)
    unless xml.elements["/directory/entry/@name='_patchinfo'"]
      # only if package does not contain a _patchinfo file
      unless DbPackage.exists_by_project_and_name(targetProject.name, basePackageName, follow_project_links=false)
        new = DbPackage.new(:name => basePackageName, :title => sourcePackage.title, :description => sourcePackage.description)
        targetProject.db_packages << new
        new.store
      end
      cp_params = {
        :user => @http_user.login,
      }
      cp_params[:comment] = "Release updateinfo #{updateinfoId}" if updateinfoId
      cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(basePackageName)}/_link"
      cp_path << build_query_from_hash(cp_params, [:user, :comment])
      Suse::Backend.put cp_path, "<link package='#{CGI.escape(targetPackageName)}' cicount='copy' />\n"
    end

  end
end
