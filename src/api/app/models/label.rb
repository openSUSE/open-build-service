# TODO: Please overwrite this comment with something explaining the model target
class Label < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
      belongs_to :labelable, polymorphic: true, required: true
      belongs_to :label_template, required: true
      delegate :color, to :label_template
      delegate :name, to :label_template
      
  
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
# Table name: labels
#
#  id                :bigint           not null, primary key
#  labelable_type    :string(255)      not null, indexed => [labelable_id, label_template_id], indexed => [labelable_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  label_template_id :bigint           not null, indexed, indexed => [labelable_type, labelable_id]
#  labelable_id      :integer          not null, indexed => [labelable_type, label_template_id], indexed => [labelable_type]
#
# Indexes
#
#  index_labels_on_label_template_id                (label_template_id)
#  index_labels_on_labelable_and_label_template     (labelable_type,labelable_id,label_template_id) UNIQUE
#  index_labels_on_labelable_type_and_labelable_id  (labelable_type,labelable_id)
#
# Foreign Keys
#
#  fk_rails_...  (label_template_id => label_templates.id)
#
