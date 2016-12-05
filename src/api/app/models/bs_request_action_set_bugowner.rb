#
class BsRequestActionSetBugowner < BsRequestAction
  #### Includes and extends
  #### Constants

  #### Self config
  def self.sti_name
    :set_bugowner
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
  def check_sanity
    super
    if person_name.blank? && group_name.blank?
      errors.add(:person_name, "Either person or group needs to be set")
    end
  end

  def execute_accept(_opts)
    object = Project.find_by_name!(target_project)
    bugowner = Role.find_by_title!("bugowner")
    if target_package
      object = object.packages.find_by_name!(target_package)
    end
    object.relationships.where("role_id = ?", bugowner).each do |r|
      r.destroy
    end
    object.add_user( person_name, bugowner, true ) if person_name # runs with ignoreLock
    object.add_group( group_name, bugowner, true ) if group_name  # runs with ignoreLock
    object.store(comment: "set_bugowner request #{bs_request.number}", request: bs_request)
  end

  def render_xml_attributes(node)
    render_xml_target(node)
    node.person name: person_name if person_name
    node.group name: group_name   if group_name
  end

  #### Alias of methods
end
