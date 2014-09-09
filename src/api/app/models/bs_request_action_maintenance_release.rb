class BsRequestActionMaintenanceRelease < BsRequestAction

  include SubmitRequestSourceDiff

  def self.sti_name
    return :maintenance_release
  end

  def is_maintenance_release?
    true
  end

  def execute_accept(opts)
    pkg = Package.get_by_project_and_name(self.source_project, self.source_package)
    
    # have a unique time stamp for release
    opts[:acceptTimeStamp] ||= Time.now

    opts[:updateinfoIDs] = release_package(pkg, self.target_project, self.target_package, nil, self)
    opts[:projectCommit] ||= {}
    opts[:projectCommit][self.target_project] = self.source_project
  end

  def per_request_cleanup(opts)
    cleanedProjects = {}
    # log release events once in target project
    opts[:projectCommit].each do |tprj, sprj|
      commit_params = {
        :cmd => 'commit',
        :user => User.current.login,
        :requestid => self.bs_request.id,
        :rev => 'latest',
        :comment => 'Releasing from project ' + sprj
      }
      commit_params[:comment] << " the update " << opts[:updateinfoIDs].join(", ") if opts[:updateinfoIDs]
      commit_path = "/source/#{URI.escape(tprj)}/_project"
      commit_path << Suse::Backend.build_query_from_hash(commit_params, [:cmd, :user, :comment, :requestid, :rev])
      Suse::Backend.post commit_path, nil

      next if cleanedProjects[sprj]
      # cleanup published binaries to save disk space on ftp server and mirrors
      Suse::Backend.post "/build/#{URI.escape(sprj)}?cmd=wipepublishedlocked", nil
      cleanedProjects[sprj] = 1
    end
    opts[:projectCommit] = {}
  end

  class LackingReleaseMaintainership < APIException
    setup 'lacking_maintainership', 403
  end

  class RepositoryWithoutReleaseTarget < APIException
    setup 'repository_without_releasetarget'
  end
  
  class RepositoryWithoutArchitecture < APIException
    setup 'repository_without_architecture'
  end

  class ArchitectureOrderMissmatch < APIException
    setup 'architecture_order_missmatch'
  end
  
  class OpenReleaseRequests < APIException
    setup 'open_release_requests'
  end

  def check_permissions!
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
      rel = rel.where('bs_request_actions.target_package = ? or bs_request_actions.target_package like ?', self.target_package, "#{tpkgprefix}.%")
    end
    
    # run search
    open_ids = rel.select('bs_requests.id').map { |r| r.id }
    
    unless open_ids.blank?
      msg = "The following open requests have the same target #{self.target_project} / #{tpkgprefix}: " + open_ids.join(', ')
      raise OpenReleaseRequests.new msg
    end

    # creating release requests is also locking the source package, therefore we require write access there.
    spkg = Package.find_by_project_and_name self.source_project, self.source_package
    unless spkg or not User.current.can_modify_package? spkg
      raise LackingReleaseMaintainership.new 'Creating a release request action requires maintainership in source package'
    end
    
  end

  def create_post_permissions_hook(opts)
    object = nil
    spkg = Package.find_by_project_and_name self.source_project, self.source_package
    if opts[:per_package_locking]
      object = spkg
    else
      object = spkg.project
    end
    unless object.enabled_for?('lock', nil, nil)
      f = object.flags.find_by_flag_and_status('lock', 'disable')
      object.flags.delete(f) if f # remove possible existing disable lock flag
      object.flags.create(:status => 'enable', :flag => 'lock')
      object.store
    end

  end

  def minimum_priority
    spkg = Package.find_by_project_and_name self.source_project, self.source_package
    return unless spkg and spkg.is_patchinfo?
    pi = Xmlhash.parse(spkg.patchinfo.dump_xml)
    pi["rating"]
  end
end
