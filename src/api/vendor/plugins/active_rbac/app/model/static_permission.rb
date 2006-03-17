# This class represents a "static permission" dataset in the database. A 
# static permission basically only is a string that can be attached to a
# role. You can then check for it being assigned to a role in your application
# code.
class StaticPermission < ActiveRecord::Base
  # static permissions have n:m relations to roles
  has_and_belongs_to_many :roles, :uniq => true

  # This method returns all roles this permission has been granted 
  # to and all of their children.
  def all_roles
    result = []

    self.roles.each { |role| result << role.descendants_and_self }

    result.flatten!
    result.uniq!

    return result
  end
  
  # We want to validate a static permission's title pretty thoroughly.
  validates_uniqueness_of :title, 
                          :message => 'is the name of an already existing static permission.'
  validates_presence_of   :title, 
                          :message => 'must be given.'
  validates_format_of     :title, 
                          :with => %r{^[\w \$\^\-\.#\*\+&'"]*$}, 
                          :message => 'must not contain invalid characters.'
  validates_length_of     :title, 
                          :in => 2..100, :allow_nil => true,
                          :too_long => 'must have less than 100 characters.', 
                          :too_short => 'must have more than two characters.'
end
