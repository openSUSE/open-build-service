module MaintenanceHelper

  # updates packages automatically generated in the backend after submitting a product file
  def create_new_maintenance_incident( maintenanceProject, baseProject = nil, request = nil )
    mi = MaintenanceIncident.new( :maintenance_db_project_id => maintenanceProject.id ) 

    tprj = nil
    DbProject.transaction do
      tprj = DbProject.new :name => mi.project_name
      tprj.project_user_role_relationships = maintenanceProject.project_user_role_relationships
      tprj.project_group_role_relationships = maintenanceProject.project_group_role_relationships
      if baseProject
        # copy as much as possible from base project
        tprj.title = baseProject.title
        tprj.description = baseProject.description
        tprj.flags = baseProject.flags
        tprj.repositories = baseProject.repositories
      else
        # mbranch call is enabling selected packages
        tprj.store
        tprj.flags.create( :position => 1, :flag => 'build', :status => "disable" )
      end
      tprj.store
      mi.db_project_id = tprj.id
      mi.save!
    end

    # set empty attribute to allow easy searches of active incidents
    at = AttribType.find_by_name("OBS:MaintenanceReleaseDate")
    Attrib.new(:db_project => tprj, :attrib_type => at).save

    # copy all packages and project source files from base project
    # we don't branch from it to keep the link target.
    if baseProject
      baseProject.db_packages.each do |pkg|
        new = DbPackage.new(:name => pkg.name, :title => pkg.title, :description => pkg.description)
        new.flags = pkg.flags
        tprj.db_packages << new
        new.save

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
      new.flags = sourcePackage.flags
#FIXME2.3 validate that there are no build enable flags
      targetProject.db_packages << new
      new.save
    end

    # get updateinfo id in case the source package comes from a maintenance project
    mi = MaintenanceIncident.find_by_db_project_id( sourcePackage.db_project_id ) 
    updateinfoId = nil
    if mi
      id_template = nil
      if a = mi.maintenance_db_project.find_attribute("OBS", "MaintenanceIdTemplate")
         id_template = a.values[0]
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
    }
    cp_params[:comment] = "Release updateinfo #{updateinfoId}" if updateinfoId
    cp_params[:requestid] = request.id if request
    cp_path = "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(targetPackageName)}"
    cp_path << build_query_from_hash(cp_params, [:cmd, :user, :oproject, :opackage, :comment, :requestid, :expand])
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
            }
            cp_params[:setupdateinfoid] = updateinfoId if updateinfoId
            cp_path = "/build/#{CGI.escape(releasetarget.target_repository.db_project.name)}/#{CGI.escape(releasetarget.target_repository.name)}/#{CGI.escape(arch.name)}/#{CGI.escape(targetPackageName)}"
            cp_path << build_query_from_hash(cp_params, [:cmd, :oproject, :opackage, :orepository, :setupdateinfoid])
            Suse::Backend.post cp_path, nil
          end
        end
        # remove maintenance release trigger in source
        if releasetarget.trigger == "maintenance"
          releasetarget.trigger = "manual"
          releasetarget.save!
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
        new.flags = sourcePackage.flags
        targetProject.db_packages << new
        new.save
      end
      Suse::Backend.put "/source/#{CGI.escape(targetProject.name)}/#{CGI.escape(basePackageName)}/_link", "<link package='#{CGI.escape(targetPackageName)}' />"
    end

    # update attribute to current version
    at = AttribType.find_by_name("OBS:MaintenanceReleaseDate")
    a = Attrib.find(:first, :conditions => ["attrib_type_id = ? AND db_project_id = ?", at.id, sourcePackage.db_project.id])
    found=nil
    a.values.each do |v|
      found=1 if v.value.to_s == timestamp.to_s
    end
    unless found
      a.values << AttribValue.new(:value => timestamp.to_s, :position => (a.values.count + 1))
    end
    a.save

  end
end
