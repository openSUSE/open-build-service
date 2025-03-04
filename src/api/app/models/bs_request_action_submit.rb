class BsRequestActionSubmit < BsRequestAction
  #### Includes and extends
  include BsRequestAction::Differ

  #### Constants

  #### Self config
  def self.sti_name
    :submit
  end

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def submit?
    true
  end

  def uniq_key
    "#{target_project}/#{target_package}"
  end

  def execute_accept(opts)
    # create package unless it exists already
    target_project = Project.get_by_name(self.target_project)

    # FIXME: when this code is moved to conditional assigment, it causes ambiguity between target_package and self.target_package.
    # Problems detected in webui/session_controller_spec.rb jobs/staging_project_accept_job_spec.rb webui/request_controller_spec.rb
    if target_package
      target_package = target_project.packages.find_by_name(self.target_package)
    else
      target_package = target_project.packages.find_by_name(source_package)
    end

    relink_source = false
    unless target_package
      # check for target project attributes
      initialize_devel_package = target_project.find_attribute('OBS', 'InitializeDevelPackage')
      # create package in database
      linked_package = target_project.find_package(self.target_package)
      if linked_package
        # exists via project links
        opts = { request: bs_request }
        opts[:makeoriginolder] = true if makeoriginolder
        instantiate_container(target_project, linked_package.update_instance, opts)
        target_package = target_project.packages.find_by_name(linked_package.name)
      else
        # check the permissions again, because the target_package could
        # have been deleted after the previous check_action_permission! call
        check_action_permission!(skip_source: true) if initialize_devel_package
        # new package, base container on source container
        newxml = Xmlhash.parse(Backend::Api::Sources::Package.meta(source_project, source_package))
        newxml['name'] = self.target_package
        newxml['devel'] = nil
        target_package = target_project.packages.new(name: newxml['name'])
        target_package.update_from_xml(newxml)
        target_package.flags.destroy_all
        target_package.remove_all_persons
        target_package.remove_all_groups
        target_package.scmsync = nil
        if initialize_devel_package
          target_package.develpackage = Package.find_by_project_and_name(source_project, source_package)
          relink_source = true
        end
        target_package.store(comment: "submit request #{bs_request.number}", request: bs_request)
      end
    end

    cp_params = {
      noservice: 1,
      requestid: bs_request.number,
      comment: bs_request.description,
      withacceptinfo: 1
    }
    cp_params[:orev] = source_rev if source_rev
    cp_params[:dontupdatesource] = 1 if sourceupdate == 'noupdate'
    unless updatelink
      cp_params[:expand] = 1
      cp_params[:keeplink] = 1
    end
    response = Backend::Api::Sources::Package.copy(self.target_project, self.target_package,
                                                   source_project, source_package, User.session!.login, cp_params)
    result = Xmlhash.parse(response)

    fill_acceptinfo(result['acceptinfo'])

    target_package.sources_changed

    # cleanup source project
    if relink_source && sourceupdate != 'noupdate'
      if Package.find_by_project_and_name(source_project, source_package).scmsync.blank?
        # source package got used as devel package, link it to the target
        # re-create it via branch , but keep current content...
        options = { comment: "initialized devel package after accepting #{bs_request.number}",
                    requestid: bs_request.number, keepcontent: 1, noservice: 1 }
        Backend::Api::Sources::Package.branch(self.target_project, self.target_package, source_project, source_package, User.session!.login, options)
      end
    elsif sourceupdate == 'cleanup'
      source_cleanup
    end

    return unless self.target_package == '_product'

    Project.find_by_name!(self.target_project).update_product_autopackages
  end

  def check_action_permission!(skip_source = nil)
    super
    # only perform the following check, if we are called from
    # BsRequest.permission_check_change_state! (that is, if
    # skip_source is set to true). Always executing this check
    # would be a regression, because this code is also executed
    # if a new request is created (which could fail if User.session!
    # cannot modify the source_package).
    return unless skip_source

    target_project = Project.get_by_name(self.target_project)
    return unless target_project && target_project.is_a?(Project)

    target_package = target_project.packages.find_by_name(self.target_package)
    initialize_devel_package = target_project.find_attribute('OBS', 'InitializeDevelPackage')
    return if target_package || !initialize_devel_package

    source_package = Package.get_by_project_and_name(source_project, self.source_package, follow_project_links: false)
    return if User.session!.can_modify?(source_package)

    msg = 'No permission to initialize the source package as a devel package'
    raise PostRequestNoPermission, msg
  end

  def name
    "Submit #{uniq_key}"
  end

  def short_name
    "Submit #{source_package}"
  end

  def creator_is_target_maintainer
    request_creator = User.find_by_login(bs_request.creator)
    request_creator.local_role?(Role.hashed['maintainer'], target_package_object)
  end

  def forward
    return [] unless target_package_object

    # add all the devel packages into the forwards
    forward_object = target_package_object.developed_packages.map do |dev_pkg|
      { project: dev_pkg.project.name, package: dev_pkg.name, type: 'devel' }
    end

    return forward_object unless (linkinfo = target_package_object.linkinfo)

    # check if the link is already in the forwards, add it otherwise
    if forward_object.none? { |forward| forward[:project] == linkinfo['project'] && forward[:package] == linkinfo['package'] }
      forward_object << { project: linkinfo['project'], package: linkinfo['package'], type: 'link' }
    end

    forward_object
  end

  def source_srcmd5
    source_package_object&.dir_hash({ rev: source_rev }.compact)&.[]('srcmd5')
  end

  def target_srcmd5
    target_package_object&.dir_hash&.[]('srcmd5')
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
