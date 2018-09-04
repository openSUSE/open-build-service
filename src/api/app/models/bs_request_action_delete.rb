#
class BsRequestActionDelete < BsRequestAction
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros

  #### Class methods using self. (public and then private)
  def self.sti_name
    :delete
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  def check_sanity
    super
    errors.add(:source_project, 'source can not be used in delete action') if source_project
    errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
    errors.add(:target_project, 'must not target package and target repository') if target_repository && target_package
  end

  def remove_repository(opts)
    prj = Project.get_by_name(target_project)
    r = prj.repositories.find_by_name(target_repository)
    unless r
      raise RepositoryMissing, "The repository #{target_project} / #{target_repository} does not exist"
    end
    r.destroy
    prj.store(lowprio: opts[:lowprio], comment: opts[:comment], request: bs_request)
  end

  def render_xml_attributes(node)
    attributes = xml_package_attributes('target')
    attributes[:repository] = target_repository if target_repository.present?
    node.target(attributes)
  end

  def sourcediff(opts = {})
    raise DiffError, "Project diff isn't implemented yet" unless target_package || target_repository
    return '' unless target_package
    begin
      options = { expand: 1, filelimit: 0, rev: 0 }
      options[:view] = 'xml' if opts[:view] == 'xml' # Request unified diff in full XML view
      Backend::Api::Sources::Package.source_diff(target_project, target_package, options)
    rescue Timeout::Error
      raise DiffError, "Timeout while diffing #{target_project}/#{target_package}"
    rescue Backend::Error => e
      raise DiffError, "The diff call for #{target_project}/#{target_package} failed: #{e.summary}"
    end
  end

  def execute_accept(opts)
    if target_repository
      remove_repository(opts)
      return
    end

    if target_package
      package = Package.get_by_project_and_name(target_project, target_package,
                                                use_source: true, follow_project_links: false)
      package.commit_opts = { comment: bs_request.description, request: bs_request }
      package.destroy
      return Package.source_path(target_project, target_package)
    else
      project = Project.get_by_name(target_project)
      project.commit_opts = { comment: bs_request.description, request: bs_request }
      project.destroy
      return "/source/#{target_project}"
    end
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
