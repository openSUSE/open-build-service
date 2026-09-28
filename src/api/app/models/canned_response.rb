# Canned responses are predetermined comment responses to common questions in a project/package/request
# Each user can manage their own set of canned responses
class CannedResponse < ApplicationRecord
  #### Includes and extends

  #### Constants
  DECISION_TYPE_DESCRIPTIONS = {
    'cleared' => 'Used when a report is dismissed because the content does not violate any policy.',
    'favored' => 'Used when a report is accepted and a moderation action is taken.',
    'favored_with_comment_moderation' => 'Used when a report is accepted and the offending comment is hidden.',
    'favored_with_delete_request' => 'Used when a report is accepted and a delete request is submitted for the content.',
    'favored_with_user_deletion' => "Used when a report is accepted and the reported user's account is deleted.",
    'favored_with_user_commenting_restriction' => 'Used when a report is accepted and the reported user is restricted from commenting.',
    nil => 'General-purpose responses not tied to any specific moderation decision.'
  }.freeze

  #### Self config
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true, length: { maximum: 65_535 }

  enum :decision_type, {
    cleared: 0,
    favored: 1,
    favored_with_comment_moderation: 2,
    favored_with_delete_request: 3,
    favored_with_user_deletion: 4,
    favored_with_user_commenting_restriction: 5
  }

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :user, optional: false
  belongs_to :project, optional: true
  belongs_to :package, optional: true
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
# Table name: canned_responses
#
#  id            :bigint           not null, primary key
#  content       :text(65535)      not null
#  decision_type :integer
#  title         :string(255)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  package_id    :integer          indexed
#  project_id    :integer          indexed
#  user_id       :integer          not null, indexed
#
# Indexes
#
#  index_canned_responses_on_package_id  (package_id)
#  index_canned_responses_on_project_id  (project_id)
#  index_canned_responses_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (package_id => packages.id) ON DELETE => nullify
#  fk_rails_...  (project_id => projects.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
