#
class BsRequestActionChangeDevel < BsRequestAction
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
    :change_devel
  end

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def execute_accept(_opts)
    target_project = Project.get_by_name(self.target_project)
    target_package = target_project.packages.find_by_name(self.target_package)
    target_package.develpackage = Package.get_by_project_and_name(source_project, source_package)

    target_package.resolve_devel_package
    target_package.store(comment: "change_devel request #{bs_request.number}", request: bs_request)
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: bs_request_actions
#
#  id                    :integer          not null, primary key
#  bs_request_id         :integer
#  type                  :string(255)
#  target_project        :string(255)
#  target_package        :string(255)
#  target_releaseproject :string(255)
#  source_project        :string(255)
#  source_package        :string(255)
#  source_rev            :string(255)
#  sourceupdate          :string(255)
#  updatelink            :boolean          default("0")
#  person_name           :string(255)
#  group_name            :string(255)
#  role                  :string(255)
#  created_at            :datetime
#  target_repository     :string(255)
#  makeoriginolder       :boolean          default("0")
#
# Indexes
#
#  bs_request_id                                                  (bs_request_id)
#  index_bs_request_actions_on_source_package                     (source_package)
#  index_bs_request_actions_on_source_project                     (source_project)
#  index_bs_request_actions_on_target_package                     (target_package)
#  index_bs_request_actions_on_target_project                     (target_project)
#  index_bs_request_actions_on_target_project_and_source_project  (target_project,source_project)
#
