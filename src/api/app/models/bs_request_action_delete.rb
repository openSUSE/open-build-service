class BsRequestActionDelete < BsRequestAction
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  validates :source_project, :source_package, :source_rev, :sourceupdate, absence: true
  validates :target_project, presence: true
  validates :target_repository, absence: { message: 'must not target package and target repository' }, if: :target_package
  validates :target_package, absence: { message: 'must not target package and target repository' }, if: :target_repository
  validates :group_name, :person_name, :role, :target_releaseproject, absence: true

  #### Class methods using self. (public and then private)
  def self.sti_name
    :delete
  end

  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)

  def uniq_key
    "#{target_project}/#{target_package}"
  end

  def render_xml_attributes(node)
    attributes = xml_package_attributes('target')
    attributes[:repository] = target_repository if target_repository.present?
    node.target(attributes)
  end

  def sourcediff(opts = {})
    if target_repository
      repository_remove_diff(view: opts[:view])
    elsif target_project && target_package
      get_sourcediff(target_project: target_project, target_package: target_package, view: opts[:view])
    elsif target_project && !target_package
      project_remove_diff(view: opts[:view])
    end
  end

  def execute_accept(opts)
    if target_repository
      remove_target_repository(comment: opts[:comment], lowprio: opts[:lowprio])
    elsif target_project && target_package
      remove_target_package(comment: opts[:comment])
    elsif target_project && !target_package
      remove_target_project(comment: opts[:comment])
    end
  end

  def name
    if target_package
      "Delete #{target_package}"
    elsif target_repository
      "Delete #{target_repository}"
    else
      "Delete #{target_project}"
    end
  end

  def short_name
    name
  end

  private

  def remove_target_project(comment: nil)
    # no need to break complex requests if a project has been removed already
    return "/source/#{target_project}" unless target_project_object

    target_project_object.commit_opts = { comment: comment, request: bs_request }.compact
    target_project_object.commit_user = commit_user if commit_user
    target_project_object.destroy
    "/source/#{target_project}"
  end

  def remove_target_package(comment: nil)
    raise Package::UnknownObjectError, "Package not found: #{target_project}/#{target_package}" unless target_package_object

    target_package_object.commit_opts = { comment: comment, request: bs_request }.compact
    target_package_object.commit_user = commit_user if commit_user
    target_package_object.destroy
    Package.source_path(target_project, target_package)
  end

  def remove_target_repository(comment: nil, lowprio: nil)
    raise Project::UnknownObjectError, "Project not found: #{target_project}" unless target_project_object

    repository = target_project_object.repositories.find_by(name: target_repository)
    raise RepositoryMissing, "Repository not found: #{target_project} / #{target_repository}" unless repository

    repository.destroy
    target_project_object.commit_opts = { comment: comment, request: bs_request, lowprio: lowprio }.compact
    target_project_object.commit_user = commit_user if commit_user
    target_project_object.store
    "/source/#{target_project}"
  end

  def repository_remove_diff(view:)
    if view == 'xml'
      ''
    else
      "- Removal of repository '#{target_repository}'"
    end
  end

  def project_remove_diff(view:)
    if view == 'xml'
      ''
    else
      "- Removal of project '#{target_project}'"
    end
  end

  def commit_user
    bs_request.creator if bs_request.accept_at
    bs_request.approver if bs_request.approver
  end

  def get_sourcediff(target_project:, target_package:, view: nil)
    Backend::Api::Sources::Package.source_diff(target_project, target_package, { expand: 1, filelimit: 0, rev: 0, view: view })
  rescue Timeout::Error
    raise DiffError, "Timeout while diffing #{target_project}/#{target_package}"
  rescue Backend::Error => e
    raise DiffError, "The diff call for #{target_project}/#{target_package} failed: #{e.summary}"
  end
end

# == Schema Information
#
# Table name: bs_request_actions
#
#  id                    :integer          not null, primary key
#  comments_count        :integer          default(0), not null, indexed
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
#  type                  :string(255)      indexed
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
#  index_bs_request_actions_on_comments_count                       (comments_count)
#  index_bs_request_actions_on_source_package                       (source_package)
#  index_bs_request_actions_on_source_package_id                    (source_package_id)
#  index_bs_request_actions_on_source_project                       (source_project)
#  index_bs_request_actions_on_source_project_id                    (source_project_id)
#  index_bs_request_actions_on_target_package                       (target_package)
#  index_bs_request_actions_on_target_package_id                    (target_package_id)
#  index_bs_request_actions_on_target_project                       (target_project)
#  index_bs_request_actions_on_target_project_id                    (target_project_id)
#  index_bs_request_actions_on_type                                 (type)
#
# Foreign Keys
#
#  bs_request_actions_ibfk_1  (bs_request_id => bs_requests.id)
#
