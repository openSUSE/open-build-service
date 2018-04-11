# frozen_string_literal: true

#
class BsRequestActionMaintenanceRelease < BsRequestAction
  #### Includes and extends
  include BsRequestAction::Differ

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

    opts[:updateinfoIDs] = release_package(pkg, Project.get_by_name(target_project), target_package, nil, nil, self)
    opts[:projectCommit] ||= {}
    opts[:projectCommit][target_project] = source_project

    # lock project when last package is released
    return if pkg.project.is_locked?
    f = pkg.project.flags.find_by_flag_and_status('lock', 'disable')
    pkg.project.flags.delete(f) if f # remove possible existing disable lock flag
    pkg.project.flags.create(status: 'enable', flag: 'lock')
    pkg.project.store(comment: 'maintenance_release request accepted')
  end

  def per_request_cleanup(opts)
    cleaned_projects = {}
    # log release events once in target project
    opts[:projectCommit].each do |tprj, sprj|
      commit_params = {
        requestid: bs_request.number,
        rev:       'latest',
        comment:   "Releasing from project #{sprj}"
      }
      commit_params[:comment] += " the update #{opts[:updateinfoIDs].join(', ')}" if opts[:updateinfoIDs]
      Backend::Api::Sources::Project.commit(tprj, User.current.login, commit_params)

      next if cleaned_projects[sprj]
      # cleanup published binaries to save disk space on ftp server and mirrors
      Backend::Api::BuildResults::Binaries.wipe_published_locked(sprj)
      cleaned_projects[sprj] = 1
    end
    opts[:projectCommit] = {}
  end

  def sanity_check!
    # get sure that the releasetarget definition exists or we release without binaries
    prj = Project.get_by_name(source_project)
    prj.repositories.includes(:release_targets).each do |repo|
      if repo.release_targets.empty?
        raise RepositoryWithoutReleaseTarget, "Release target definition is missing in #{prj.name} / #{repo.name}"
      end
      if repo.architectures.empty?
        raise RepositoryWithoutArchitecture, "Repository has no architecture #{prj.name} / #{repo.name}"
      end
      repo.release_targets.each do |rt|
        unless repo.architectures.size == rt.target_repository.architectures.size
          raise ArchitectureOrderMissmatch, "Repository '#{repo.name}' and releasetarget " \
                                            "'#{rt.target_repository.name}' have different architectures"
        end
        for i in 1..(repo.architectures.size)
          unless repo.architectures[i - 1] == rt.target_repository.architectures[i - 1]
            raise ArchitectureOrderMissmatch, "Repository and releasetarget don't have the same architecture " \
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
    xml = REXML::Document.new(Backend::Api::Sources::Package.files(source_project, source_package))
    rel = BsRequest.where(state: [:new, :review]).joins(:bs_request_actions)
    rel = rel.where(bs_request_actions: { target_project: target_project })
    if xml.elements["/directory/entry/@name='_patchinfo'"]
      rel = rel.where(bs_request_actions: { target_package: target_package })
    else
      tpkgprefix = target_package.gsub(/\.[^\.]*$/, '')
      rel = rel.where('bs_request_actions.target_package = ? or bs_request_actions.target_package like ?', target_package, "#{tpkgprefix}.%")
    end

    # run search
    open_ids = rel.select('bs_requests').pluck(:number)
    open_ids.delete(bs_request.number) if bs_request
    if open_ids.count > 0
      msg = "The following open requests have the same target #{target_project} / #{tpkgprefix}: " + open_ids.join(', ')
      raise OpenReleaseRequests, msg
    end

    # creating release requests is also locking the source package, therefore we require write access there.
    spkg = Package.find_by_project_and_name source_project, source_package
    return if spkg || !User.current.can_modify_package?(spkg)
    raise LackingReleaseMaintainership, 'Creating a release request action requires maintainership in source package'
  end

  def set_acceptinfo(ai)
    # packages in maintenance_release projects are expanded copies, so we can not use
    # the link information. We need to patch the "old" part
    base_package_name = target_package.gsub(/\.[^\.]*$/, '')
    pkg = Package.find_by_project_and_name(target_project, base_package_name)
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
    return if object.enabled_for?('lock', nil, nil)

    object.check_write_access!(true)
    f = object.flags.find_by_flag_and_status('lock', 'disable')
    object.flags.delete(f) if f # remove possible existing disable lock flag
    object.flags.create(status: 'enable', flag: 'lock')
    object.store(comment: 'maintenance_release request')
  end

  def minimum_priority
    spkg = Package.find_by_project_and_name source_project, source_package
    return unless spkg && spkg.is_patchinfo?
    pi = Xmlhash.parse(spkg.patchinfo.dump_xml)
    pi['rating']
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: bs_request_actions
#
#  id                    :integer          not null, primary key
#  bs_request_id         :integer          indexed, indexed => [target_package_id], indexed => [target_project_id]
#  type                  :string(255)
#  target_project        :string(255)      indexed
#  target_package        :string(255)      indexed
#  target_releaseproject :string(255)
#  source_project        :string(255)      indexed
#  source_package        :string(255)      indexed
#  source_rev            :string(255)
#  sourceupdate          :string(255)
#  updatelink            :boolean          default(FALSE)
#  person_name           :string(255)
#  group_name            :string(255)
#  role                  :string(255)
#  created_at            :datetime
#  target_repository     :string(255)
#  makeoriginolder       :boolean          default(FALSE)
#  target_package_id     :integer          indexed => [bs_request_id], indexed
#  target_project_id     :integer          indexed => [bs_request_id], indexed
#
# Indexes
#
#  bs_request_id                                                    (bs_request_id)
#  index_bs_request_actions_on_bs_request_id_and_target_package_id  (bs_request_id,target_package_id)
#  index_bs_request_actions_on_bs_request_id_and_target_project_id  (bs_request_id,target_project_id)
#  index_bs_request_actions_on_source_package                       (source_package)
#  index_bs_request_actions_on_source_project                       (source_project)
#  index_bs_request_actions_on_target_package                       (target_package)
#  index_bs_request_actions_on_target_package_id                    (target_package_id)
#  index_bs_request_actions_on_target_project                       (target_project)
#  index_bs_request_actions_on_target_project_id                    (target_project_id)
#
# Foreign Keys
#
#  bs_request_actions_ibfk_1  (bs_request_id => bs_requests.id)
#
