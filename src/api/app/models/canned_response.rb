# Canned responses are predetermined comment responses to common questions in a project/package/request
# Each user can manage their own set of canned responses
class CannedResponse < ApplicationRecord
  #### Includes and extends

  #### Constants

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
#  user_id       :integer          not null, indexed
#
# Indexes
#
#  index_canned_responses_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
