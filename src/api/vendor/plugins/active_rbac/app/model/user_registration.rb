# UserRegistration objects represent user_registration records in the database.
# They hold a registration confirmation token, an expiry time and are 
# associated with users.
#
# Developers must not create them manually, but use 
# User.create_user_registration!
class UserRegistration < ActiveRecord::Base
  # user_registrations have a n:1 relation to users
  belongs_to :user

  # Initialize sets the expires_at and token property. Thus we need no 
  # validation since everything is set automatically anyway.
  def initialize(arguments=nil)
    super(arguments)
    
    self.expires_at = Time.now + (60 * 60 * 24)
    self.token = Digest::MD5.hexdigest(expires_at.to_s + '--' + rand.to_s).slice(1,10)
  end
  
  # Returns true if this token has expired.
  def expired?
    expires_at > Time.now
  end

  # We only need to validate the token here.
  validates_format_of     :token, 
                          :with => %r{^[\w]*$}, 
                          :message => 'must not contain invalid characters.'
  validates_length_of     :token, 
                          :is => 10,
                          :too_long => 'must have exactly 10 characters.'
end
