class User < ActiveRecord::Base
  include ActiveRbacMixins::UserMixin

  has_many :taggings, :dependent => :destroy
  has_many :tags, :through => :taggings

  has_many :watched_projects, :foreign_key => 'bs_user_id'
  has_many :project_user_role_relationships, :foreign_key => 'bs_user_id'
  has_many :package_user_role_relationships, :foreign_key => 'bs_user_id'

  has_many :status_messages


  def encrypt_password
    if errors.count == 0 and @new_password and not password.nil?
      # generate a new 10-char long hash only Base64 encoded so things are compatible
      self.password_salt = [Array.new(10){rand(256).chr}.join].pack("m")[0..9];

      # write encrypted password to object property

      # vvvvvv added this to maintain the password list for lighttpd
      write_attribute(:password_crypted, password.crypt("os"))
      #  ^^^^^^
      write_attribute(:password, hash_string(password))

      # mark password as "not new" any more
      @new_password = false
      password_confirmation = nil
    else 
      logger.debug "Error - skipping to create user"
    end
  end

  # Returns true if the the state transition from "from" state to "to" state
  # is valid. Returns false otherwise. +new_state+ must be the integer value
  # of the state as returned by +User.states['state_name']+.
  #
  # Note that currently no permission checking is included here; It does not
  # matter what permissions the currently logged in user has, only that the
  # state transition is legal in principle.
  def state_transition_allowed?(from, to)
    from = from.to_i
    to = to.to_i
    return true if from == to # allow keeping state
    return case from
      when states['unconfirmed']
        true
      when states['confirmed']
        (to == states['locked']) or (to == states['deleted']) or (to == states['ichainrequest'])
      when states['locked']
        (to == states['confirmed']) or (to == states['deleted'])
      when states['deleted']
        to == states['confirmed']
      when states['ichainrequest']
        (to == states['locked']) or (to == states['confirmed']) or (to == states['deleted'])
      when 0
        states.value?(to)
      else
        false
    end
  end
 
  def states
    # logger.debug "Using our states"
    s = {
        'unconfirmed' => 1,
        'confirmed' => 2,
        'locked' => 3,
        'deleted' => 4,
        'ichainrequest' => 5
    }
    return s
  end

end

