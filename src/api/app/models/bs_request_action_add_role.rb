#
class BsRequestActionAddRole < BsRequestAction
  def self.sti_name
    :add_role
  end

  def check_sanity
    super
    errors.add(:role, 'should not be empty for add_role') if role.blank?
    person_or_group_present
  end

  def execute_accept(opts)
    object.add_user(person_name, role_object, opts[:ignore_lock]) if person_name
    object.add_group(group_name, role_object, opts[:ignore_lock]) if group_name

    object.store(comment: "#{type} request #{bs_request.number}", request: bs_request)
  end

  def render_xml_attributes(node)
    render_xml_target(node)
    node.person(name: person_name, role: role) if person_name
    node.group(name: group_name, role: role) if group_name
  end

  protected

  def person_or_group_present
    return unless person_name.blank? && group_name.blank?
    errors.add(:person_name, 'Either person or group needs to be set')
  end

  def object
    unless @object
      @object = Project.find_by_name!(target_project)
      @object.packages.find_by_name(target_package) if target_package
    end
    @object
  end

  def role_object
    @role_object ||= Role.find_by_title!(role)
  end
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
