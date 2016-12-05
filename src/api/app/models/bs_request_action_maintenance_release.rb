#
class BsRequestActionMaintenanceRelease < BsRequestAction
  #### Includes and extends
  include RequestSourceDiff

  #### Constants

  #### Self config
  class LackingReleaseMaintainership < APIException; setup 'lacking_maintainership', 403; end
  class RepositoryWithoutReleaseTarget < APIException; setup 'repository_without_releasetarget'; end
  class RepositoryWithoutArchitecture < APIException; setup 'repository_without_architecture'; end
  class ArchitectureOrderMissmatch < APIException; setup 'architecture_order_missmatch'; end
  class OpenReleaseRequests < APIException; setup 'open_release_requests'; end

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  before_create :sanity_check!

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :maintenance_release
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def is_maintenance_release?
    true
  end

  def execute_accept(opts)
    pkg = Package.get_by_project_and_name(source_project, source_package)

    # have a unique time stamp for release
    opts[:acceptTimeStamp] ||= Time.now

    opts[:updateinfoIDs] = release_package(pkg, Project.get_by_name(target_project), target_package, nil, self)
    opts[:projectCommit] ||= {}
    opts[:projectCommit][target_project] = source_project

    # lock project when last package is released
    return if pkg.project.is_locked?
    f = pkg.project.flags.find_by_flag_and_status('lock', 'disable')
    pkg.project.flags.delete(f) if f # remove possible existing disable lock flag
    pkg.project.flags.create(status: 'enable', flag: 'lock')
    pkg.project.store(comment: "maintenance_release request accepted")
  end

  def per_request_cleanup(opts)
    cleanedProjects = {}
    # log release events once in target project
    opts[:projectCommit].each do |tprj, sprj|
      commit_params = {
        cmd:       "commit",
        user:      User.current.login,
        requestid: bs_request.number,
        rev:       "latest",
        comment:   "Releasing from project #{sprj}"
      }
      commit_params[:comment] << " the update " << opts[:updateinfoIDs].join(", ") if opts[:updateinfoIDs]
      commit_path = "/source/#{URI.escape(tprj)}/_project"
      commit_path << Suse::Backend.build_query_from_hash(commit_params, [:cmd, :user, :comment, :requestid, :rev])
      Suse::Backend.post commit_path

      next if cleanedProjects[sprj]
      # cleanup published binaries to save disk space on ftp server and mirrors
      Suse::Backend.post "/build/#{URI.escape(sprj)}?cmd=wipepublishedlocked"
      cleanedProjects[sprj] = 1
    end
    opts[:projectCommit] = {}
  end

  def sanity_check!
    # get sure that the releasetarget definition exists or we release without binaries
    prj = Project.get_by_name(source_project)
    prj.repositories.includes(:release_targets).each do |repo|
      unless repo.release_targets.size > 0
        raise RepositoryWithoutReleaseTarget.new "Release target definition is missing in #{prj.name} / #{repo.name}"
      end
      unless repo.architectures.size > 0
        raise RepositoryWithoutArchitecture.new "Repository has no architecture #{prj.name} / #{repo.name}"
      end
      repo.release_targets.each do |rt|
        unless repo.architectures.size == rt.target_repository.architectures.size
          raise ArchitectureOrderMissmatch.new "Repository '#{repo.name}' and releasetarget " +
                                               "'#{rt.target_repository.name}' have different architectures"
        end
        for i in 1..(repo.architectures.size)
          unless repo.architectures[i-1] == rt.target_repository.architectures[i-1]
            raise ArchitectureOrderMissmatch.new "Repository and releasetarget don't have the same architecture " +
                                                 "on position #{i}: #{prj.name} / #{repo.name}"
          end
        end
      end
    end
  end

  def check_permissions!
    sanity_check!

    # check for open release requests with same target, the binaries can't get merged automatically
    # either exact target package match or with same prefix (when using the incident extension)

    # patchinfos don't get a link, all others should not conflict with any other
    # FIXME2.4 we have a directory model
    answer = Suse::Backend.get "/source/#{CGI.escape(source_project)}/#{CGI.escape(source_package)}"
    xml = REXML::Document.new(answer.body.to_s)
    rel = BsRequest.where(state: [:new, :review]).joins(:bs_request_actions)
    rel = rel.where(bs_request_actions: { target_project: target_project })
    if xml.elements["/directory/entry/@name='_patchinfo'"]
      rel = rel.where(bs_request_actions: { target_package: target_package } )
    else
      tpkgprefix = target_package.gsub(/\.[^\.]*$/, '')
      rel = rel.where('bs_request_actions.target_package = ? or bs_request_actions.target_package like ?', target_package, "#{tpkgprefix}.%")
    end

    # run search
    open_ids = rel.select('bs_requests').pluck(:number)
    open_ids.delete(bs_request.number) if bs_request
    if open_ids.count > 0
      msg = "The following open requests have the same target #{target_project} / #{tpkgprefix}: " + open_ids.join(', ')
      raise OpenReleaseRequests.new msg
    end

    # creating release requests is also locking the source package, therefore we require write access there.
    spkg = Package.find_by_project_and_name source_project, source_package
    unless spkg || !User.current.can_modify_package?(spkg)
      raise LackingReleaseMaintainership.new 'Creating a release request action requires maintainership in source package'
    end
  end

  def set_acceptinfo(ai)
    # packages in maintenance_release projects are expanded copies, so we can not use
    # the link information. We need to patch the "old" part
    basePackageName = target_package.gsub(/\.[^\.]*$/, '')
    pkg = Package.find_by_project_and_name( target_project, basePackageName )
    if pkg
      opkg = pkg.origin_container
      if opkg.name != target_package || opkg.project.name != target_project
        ai['oproject'] = opkg.project.name
        ai['opackage'] = opkg.name
        ai['osrcmd5'] = opkg.backend_package.srcmd5
        ai['oxsrcmd5'] = opkg.backend_package.expandedmd5 if opkg.backend_package.expandedmd5
      end
    end
    self.bs_request_action_accept_info = BsRequestActionAcceptInfo.create(ai)
  end

  def create_post_permissions_hook(opts)
    object = nil
    spkg = Package.find_by_project_and_name source_project, source_package
    if opts[:per_package_locking]
      # we avoid patchinfo's to be able to complete meta data about the update
      return if spkg.is_patchinfo?
      object = spkg
    else
      # Workaround: In rails 5 'spkg.project' started to return a readonly object
      object = Project.find(spkg.project_id)
    end
    unless object.enabled_for?('lock', nil, nil)
      object.check_write_access!(true)
      f = object.flags.find_by_flag_and_status('lock', 'disable')
      object.flags.delete(f) if f # remove possible existing disable lock flag
      object.flags.create(status: 'enable', flag: 'lock')
      object.store(comment: "maintenance_release request")
    end
  end

  def minimum_priority
    spkg = Package.find_by_project_and_name source_project, source_package
    return unless spkg && spkg.is_patchinfo?
    pi = Xmlhash.parse(spkg.patchinfo.dump_xml)
    pi["rating"]
  end

  #### Alias of methods
end
