# TODO: Please overwrite this comment with something explaining the model target
class SavedReply < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :user
  
  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :title, :body, presence: true

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private


  #### Instance methods (public and then protected/private)

  #### Alias of methods
  
end

# == Schema Information
#
# Table name: saved_replies
#
#  id         :integer          not null, primary key
#  body       :string(255)
#  title      :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_saved_replies_on_user_id  (user_id)
#
