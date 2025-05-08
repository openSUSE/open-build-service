# TODO: Please overwrite this comment with something explaining the model target
class LabelGlobal < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :project, optional: false
  belongs_to :label_template_global, optional: false
  delegate :color, to: :label_template_global
  delegate :name, to: :label_template_global

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :project_id, uniqueness: { scope: :label_template_global_id }

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  alias label_template label_template_global
end

# == Schema Information
#
# Table name: label_globals
#
#  id                       :bigint           not null, primary key
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  label_template_global_id :bigint           not null, indexed, indexed => [project_id]
#  project_id               :integer          not null, indexed => [label_template_global_id], indexed
#
# Indexes
#
#  index_label_globals_on_label_template_global_id           (label_template_global_id)
#  index_label_globals_on_project_and_label_template_global  (project_id,label_template_global_id) UNIQUE
#  index_label_globals_on_project_id                         (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (label_template_global_id => label_template_globals.id)
#  fk_rails_...  (project_id => projects.id)
#
