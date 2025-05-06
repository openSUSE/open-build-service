# TODO: Please overwrite this comment with something explaining the model target
class Label < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :labelable, polymorphic: true, optional: false
  belongs_to :label_template, optional: false
  delegate :color, to: :label_template
  delegate :name, to: :label_template

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :labelable_type, length: { maximum: 255 }
  validates :labelable_id, uniqueness: { scope: %i[labelable_type label_template_id] }
  validate :bs_request_has_one_target_project
  validate :validate_labelable_label_template_association
  #### Class methods using self. (public and then private)

  def project_for_labels
    return labelable.project unless labelable.is_a?(BsRequest)

    target_project_ids = labelable.bs_request_actions.pluck(:target_project_id).uniq
    return if target_project_ids.count > 1

    Project.find_by(id: target_project_ids.last)
  end

  #### To define class methods as private use private_class_method
  #### private
  private

  def bs_request_has_one_target_project
    errors.add(:labelable, 'Labeling requests with more than one target project is not allowed') if project_for_labels.nil?
  end

  def validate_labelable_label_template_association
    project = project_for_labels
    return if project.nil? || project.label_templates.include?(label_template)

    errors.add(:base, :invalid, message: 'Labelable and LabelTemplate are not associated')
  end

  #### Instance methods (public and then protected/private)

  #### Alias of methods
end

# == Schema Information
#
# Table name: labels
#
#  id                :bigint           not null, primary key
#  labelable_type    :string(255)      not null, indexed => [labelable_id, label_template_id]
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  label_template_id :bigint           not null, indexed, indexed => [labelable_type, labelable_id]
#  labelable_id      :integer          not null, indexed => [labelable_type, label_template_id]
#
# Indexes
#
#  index_labels_on_label_template_id             (label_template_id)
#  index_labels_on_labelable_and_label_template  (labelable_type,labelable_id,label_template_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (label_template_id => label_templates.id)
#
