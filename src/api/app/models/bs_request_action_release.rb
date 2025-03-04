class BsRequestActionRelease < BsRequestAction
  #### Includes and extends
  include BsRequestAction::Differ
  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  before_create :sanity_check!

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :release
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)

  # For consistency reasons with the other BsRequestActions
  def release?
    true
  end

  def uniq_key
    return "#{target_project}/#{target_package}/#{target_repository}" if target_repository.present?

    "#{target_project}/#{target_package}"
  end

  def execute_accept(opts)
    pkg = Package.get_by_project_and_name(source_project, source_package)

    # have a unique time stamp for release
    opts[:acceptTimeStamp] ||= Time.zone.now

    release_package(pkg, Project.get_by_name(target_project), target_package, { action: self, manual: true })
  end

  def check_permissions!
    sanity_check!
  end

  # For consistency reasons with the other BsRequestActions
  def fill_acceptinfo(acceptinfo)
    # released packages are expanded copies, so we can not use
    # the link information. We need to patch the "old" part
    base_package_name = target_package.gsub(/\.[^.]*$/, '')
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
    self.bs_request_action_accept_info = BsRequestActionAcceptInfo.create(acceptinfo)
  end

  def minimum_priority
    spkg = Package.find_by_project_and_name(source_project, source_package)
    return unless spkg && spkg.patchinfo?

    pi = Xmlhash.parse(spkg.patchinfo.document.to_xml)
    pi['rating']
  end

  def name
    "Release #{uniq_key}"
  end

  def short_name
    "Release #{source_package}"
  end

  private

  def sanity_check!
    # get sure that the releasetarget definition exists or we release without binaries
    prj = Project.get_by_name(source_project)
    manual_targets = prj.repositories.includes(:release_targets).where(release_targets: { trigger: 'manual' })
    raise RepositoryWithoutReleaseTarget, "Release target definition is missing in #{prj.name}" unless manual_targets.any?

    manual_targets.each do |repo|
      raise RepositoryWithoutArchitecture, "Repository has no architecture #{prj.name} / #{repo.name}" if repo.architectures.empty?

      repo.release_targets.each do |rt|
        repo.check_valid_release_target!(rt.target_repository)
      end
    end
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
