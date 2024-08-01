# TODO: Please overwrite this comment with something explaining the model target
class LabelTemplate < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
      belongs_to :project, required: true
  
  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private


  #### Instance methods (public and then protected/private)

  #### Alias of methods
  
end

# == Schema Information
#
# Table name: label_templates
#
#  id         :bigint           not null, primary key
#  color      :integer
#  name       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :integer          not null, indexed
#
# Indexes
#
#  index_label_templates_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
