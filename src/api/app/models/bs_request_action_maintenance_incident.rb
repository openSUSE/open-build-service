class BsRequestActionMaintenanceIncident < BsRequestAction
  #### Includes and extends
  include BsRequestAction::Differ

  #### Constants

  #### Self config
  class NoMaintenanceReleaseTarget < APIError
    setup 'no_maintenance_release_target'
  end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :maintenance_incident
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def maintenance_incident?
    true
  end

  def uniq_key
    # source_package should be actually release_name, but this would be a speed burden here atm.
    "#{target_project}/#{source_package}/#{target_releaseproject}"
  end

  def get_releaseproject(pkg, tprj)
    return if pkg.patchinfo?

    releaseproject = target_releaseproject ? Project.get_by_name(target_releaseproject) : tprj
    if releaseproject.try(:name).blank?
      raise NoMaintenanceReleaseTarget, 'Maintenance incident request contains no defined release ' \
                                        "target project for package #{pkg.name}"
    end

    # Automatically switch to update project
    releaseproject = releaseproject.update_instance_or_self
    unless releaseproject.maintenance_release?
      raise NoMaintenanceReleaseTarget, 'Maintenance incident request contains release target ' \
                                        "project #{releaseproject.name} with invalid project " \
                                        "kind \"#{releaseproject.kind}\" (should be " \
                                        "\"maintenance_release\") for package #{pkg.name}"
    end
    releaseproject
  end

  def sourcediff(opts = {})
    unless opts[:view] == 'xml'
      # skip local links
      hash = Directory.hashed(project: source_project, package: source_package)
      return '' if hash['linkinfo'] && hash['linkinfo']['project'] == source_project
    end
    super
  end

  def merge_into_maintenance_incident(incident_project)
    # copy all or selected packages and project source files from base project
    # we don't branch from it to keep the link target.
    pkg = _merge_pkg_into_maintenance_incident(incident_project)

    incident_project.save!
    incident_project.store(comment: "maintenance_incident request #{bs_request.number}", request: bs_request)
    pkg
  end

  def execute_accept(opts)
    # create or merge into incident project
    incident_project = Project.get_by_name(target_project)

    # the incident got created before
    self.target_package = merge_into_maintenance_incident(incident_project)

    # update action with real target project
    self.target_project = incident_project.name

    source_cleanup if sourceupdate == 'cleanup'

    # create a patchinfo if missing and incident has just been created
    Patchinfo.new.create_patchinfo_from_request(incident_project, bs_request) if opts[:check_for_patchinfo] && !incident_project.packages.joins(:package_kinds).where("kind = 'patchinfo'").exists?

    save
  end

  def expand_targets(ignore_build_state, ignore_delegate)
    # find maintenance project
    maintenance_project = nil
    if target_project
      maintenance_project = Project.get_by_name(target_project)
    else
      maintenance_project = Project.get_maintenance_project!
      self.target_project = maintenance_project.name
    end
    unless maintenance_project.maintenance_incident? || maintenance_project.maintenance?
      raise NoMaintenanceProject,
            'Maintenance incident requests have to go to projects of type maintenance or maintenance_incident'
    end
    raise IllegalRequest, 'Target package must not be specified in maintenance_incident actions' if target_package

    super
  end

  def name
    "Incident #{uniq_key}"
  end

  def short_name
    "Incident #{source_package}"
  end

  private

  def _merge_pkg_into_maintenance_incident(incident_project)
    # recreate package based on link target and throw everything away, except source changes
    # silently as maintenance teams requests ...
    new_pkg = nil

    # find link target
    dir_hash = Directory.hashed(project: source_project, package: source_package)
    linkinfo = dir_hash['linkinfo']
    if linkinfo && linkinfo['project'] == source_project
      # local link, skip it, it will come via branch command
      return
    end

    kinds = Package.detect_package_kinds(dir_hash)
    pkg_title = ''
    pkg_description = ''

    # patchinfos are handled as new packages
    if kinds.include?('patchinfo')
      if Package.exists_by_project_and_name(incident_project.name, source_package, follow_project_links: false)
        new_pkg = Package.get_by_project_and_name(incident_project.name, source_package, use_source: false, follow_project_links: false)
      else
        new_pkg = incident_project.packages.create(name: source_package, title: pkg_title, description: pkg_description)
        new_pkg.flags.create(status: 'enable', flag: 'build')
        new_pkg.flags.create(status: 'enable', flag: 'publish') unless incident_project.flags.find_by_flag_and_status('access', 'disable')
        new_pkg.store(comment: "maintenance_incident request #{bs_request.number}", request: bs_request)
      end

      # use specified release project if defined
    elsif target_releaseproject
      package_name = source_package
      package_name = linkinfo['package'] if linkinfo

      branch_params = { target_project: incident_project.name,
                        olinkrev: 'base',
                        requestid: bs_request.number,
                        maintenance: 1,
                        force: 1,
                        newinstance: 1,
                        comment: 'Initial new branch from specified release project',
                        project: target_releaseproject, package: package_name }
      # accept branching from former update incidents or GM (for kgraft case)
      linkprj = Project.find_by_name(linkinfo['project']) if linkinfo
      if defined?(linkprj) && linkprj && (linkprj.maintenance_incident? || linkprj != linkprj.update_instance_or_self || kinds.include?('channel'))
        branch_params[:project] = linkinfo['project']
        branch_params[:ignoredevel] = '1'
      end
      # it is fine to have new packages
      branch_params[:missingok] = 1 unless Package.exists_by_project_and_name(branch_params[:project], package_name)
      ret = BranchPackage.new(branch_params).branch
      new_pkg = Package.get_by_project_and_name(ret[:data][:targetproject], ret[:data][:targetpackage])

      # use link target as fallback
    elsif linkinfo && !linkinfo['missingok']
      # linked to an existing package in an external project
      linked_project = linkinfo['project']
      linked_package = linkinfo['package']

      branch_params = { target_project: incident_project.name,
                        olinkrev: 'base',
                        requestid: bs_request.number,
                        maintenance: 1,
                        force: 1,
                        comment: 'Initial new branch',
                        project: linked_project, package: linked_package }
      ret = BranchPackage.new(branch_params).branch
      new_pkg = Package.get_by_project_and_name(ret[:data][:targetproject], ret[:data][:targetpackage])
    elsif linkinfo && linkinfo['package'] # a new package for all targets
      if Package.exists_by_project_and_name(incident_project.name, source_package, follow_project_links: false)
        new_pkg = Package.get_by_project_and_name(incident_project.name, source_package, use_source: false, follow_project_links: false)
      else
        new_pkg = Package.new(name: source_package, title: pkg.title, description: pkg.description)
        incident_project.packages << new_pkg
        new_pkg.store(comment: "maintenance_incident request #{bs_request.number}", request: bs_request)
      end
    else
      # no link and not a patchinfo
      return # error out instead ?
    end

    # backend copy of submitted sources, but keep link
    cp_params = {
      requestid: bs_request.number,
      keeplink: 1,
      expand: 1,
      withacceptinfo: 1,
      comment: "Maintenance incident copy from project #{source_project}"
    }
    cp_params[:orev] = source_rev if source_rev
    response = Backend::Api::Sources::Package.copy(incident_project.name, new_pkg.name, source_project, source_package, User.session!.login, cp_params)
    result = Xmlhash.parse(response)
    fill_acceptinfo(result['acceptinfo'])

    new_pkg.sources_changed
    new_pkg
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: bs_request_actions
#
#  id                    :integer          not null, primary key
#  group_name            :string(255)
#  makeoriginolder       :boolean          default(FALSE)
#  person_name           :string(255)
#  role                  :string(255)
#  source_package        :string(255)      indexed
#  source_project        :string(255)      indexed
#  source_rev            :string(255)
#  sourceupdate          :string(255)
#  target_package        :string(255)      indexed
#  target_project        :string(255)      indexed
#  target_releaseproject :string(255)
#  target_repository     :string(255)
#  type                  :string(255)
#  updatelink            :boolean          default(FALSE)
#  created_at            :datetime
#  bs_request_id         :integer          indexed, indexed => [target_package_id], indexed => [target_project_id]
#  source_package_id     :integer          indexed
#  source_project_id     :integer          indexed
#  target_package_id     :integer          indexed => [bs_request_id], indexed
#  target_project_id     :integer          indexed => [bs_request_id], indexed
#
# Indexes
#
#  bs_request_id                                                    (bs_request_id)
#  index_bs_request_actions_on_bs_request_id_and_target_package_id  (bs_request_id,target_package_id)
#  index_bs_request_actions_on_bs_request_id_and_target_project_id  (bs_request_id,target_project_id)
#  index_bs_request_actions_on_source_package                       (source_package)
#  index_bs_request_actions_on_source_package_id                    (source_package_id)
#  index_bs_request_actions_on_source_project                       (source_project)
#  index_bs_request_actions_on_source_project_id                    (source_project_id)
#  index_bs_request_actions_on_target_package                       (target_package)
#  index_bs_request_actions_on_target_package_id                    (target_package_id)
#  index_bs_request_actions_on_target_project                       (target_project)
#  index_bs_request_actions_on_target_project_id                    (target_project_id)
#
# Foreign Keys
#
#  bs_request_actions_ibfk_1  (bs_request_id => bs_requests.id)
#
