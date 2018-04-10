# frozen_string_literal: true
require 'xmlhash'

class PersonController < ApplicationController
  validate_action userinfo: { method: :get, response: :user }
  validate_action userinfo: { method: :put, request: :user, response: :status }
  validate_action grouplist: { method: :get, response: :directory }
  validate_action register: { method: :put, response: :status }
  validate_action register: { method: :post, response: :status }

  skip_before_action :extract_user, only: [:command, :register]
  skip_before_action :require_login, only: [:command, :register]

  before_action :set_user, only: [:post_userinfo, :change_my_password]

  def show
    if params[:prefix]
      @list = User.where('login LIKE ?', params[:prefix] + '%')
    else
      @list = User.all
    end
  end

  def login
    render_ok # just a dummy check for the webui to call (for now)
  end

  # Returns a list of all users (that optionally start with a prefix)
  def command
    if params[:cmd] == 'register'
      internal_register
      return
    end
    raise UnknownCommandError, "Allowed commands are 'change_password'"
  end

  def get_userinfo
    user = User.find_by_login!(params[:login])

    if user.login != User.current.login
      logger.debug "Generating for user from parameter #{user.login}"
      render xml: user.render_axml(User.current.is_admin?)
    else
      logger.debug "Generating user info for logged in user #{User.current.login}"
      render xml: User.current.render_axml(true)
    end
  end

  def post_userinfo
    authorize @user, :update?

    login = params[:login]
    # just for permission checking
    User.find_by_login!(login)

    if params[:cmd] == 'change_password'
      login ||= User.current.login
      password = request.raw_post.to_s.chomp
      if (login != User.current.login && !User.current.is_admin?) || !::Configuration.passwords_changable?(User.current)
        render_error status: 403, errorcode: 'change_password_no_permission',
                     message: "No permission to change password for user #{login}"
        return
      end
      if password.blank?
        render_error status: 404, errorcode: 'password_empty',
                     message: 'No new password given in first line of the body'
        return
      end
      change_password(login, password)
      render_ok
      return
    end
    if params[:cmd] == 'lock'
      return unless require_admin
      user = User.find_by_login!(params[:login])
      user.lock!
      render_ok
      return
    end
    if params[:cmd] == 'delete'
      # maybe we should allow the users to delete themself?
      return unless require_admin
      user = User.find_by_login!(params[:login])
      user.delete!
      render_ok
      return
    end
    raise UnknownCommandError, "Allowed commands are 'change_password', 'lock' or 'delete', got #{params[:cmd]}"
  end

  def put_userinfo
    login = params[:login]
    user = User.find_by_login(login) if login

    unless ::Configuration.accounts_editable?(user)
      render_error(status: 403, errorcode: 'change_userinfo_no_permission',
                   message: "no permission to change userinfo for user #{user.login}")
      return
    end

    if user
      unless user.login == User.current.login || User.current.is_admin?
        logger.debug 'User has no permission to change userinfo'
        render_error(status: 403, errorcode: 'change_userinfo_no_permission',
          message: "no permission to change userinfo for user #{user.login}") && return
      end
    elsif User.current.is_admin?
      user = User.create(login: login, password: 'notset', email: 'TEMP')
      user.state = 'locked'
    else
      logger.debug 'Tried to create non-existing user without admin rights'
      @errorcode = 404
      @summary = 'Requested non-existing user'
      render_error(status: @errorcode) && return
    end

    xml = Xmlhash.parse(request.raw_post)
    logger.debug("XML: #{request.raw_post}")
    user.email = xml.value('email') || ''
    user.realname = xml.value('realname') || ''
    if User.current.is_admin?
      # only admin is allowed to change these, ignore for others
      user.state = xml.value('state')
      update_globalroles(user, xml)
      user.update(ignore_auth_services: xml.value('ignore_auth_services').to_s == 'true')

      if xml['owner']
        user.state = :subaccount
        user.owner = User.find_by_login! xml['owner']['userid']
        if user.owner.owner
          render_error(status: 400, errorcode: 'subaccount_chaining',
            message: "A subaccount can not be assigned to subaccount #{user.owner.login}") && return
        end
      end
    end
    update_watchlist(user, xml)
    user.save!
    render_ok
  end

  class NoPermissionToGroupList < APIException
    setup 401, 'No user logged in, permission to grouplist denied'
  end

  def grouplist
    raise NoPermissionToGroupList unless User.current

    user = User.find_by_login! params[:login]
    @list = User.lookup_strategy.groups(user)
  end

  def register
    # FIXME: 3.0, to be removed
    internal_register
  end

  class ErrRegisterSave < APIException
  end

  def internal_register
    if ::Configuration.ldap_enabled?
      render_error(
        status: 403,
        errorcode: 'permission_denied',
        message: 'User accounts can not be registered via OBS when in LDAP mode. Please refer to your LDAP server to create new users.'
      )
      return
    end

    xml = REXML::Document.new(request.raw_post)

    logger.debug("register XML: #{request.raw_post}")

    login = xml.elements['/unregisteredperson/login'].text
    realname = xml.elements['/unregisteredperson/realname'].text
    email = xml.elements['/unregisteredperson/email'].text
    password = xml.elements['/unregisteredperson/password'].text
    note = xml.elements['/unregisteredperson/note'].text if xml.elements['/unregisteredperson/note']
    status = xml.elements['/unregisteredperson/state'].text if xml.elements['/unregisteredperson/status']

    if authenticator.proxy_mode?
      if request.env['HTTP_X_USERNAME'].blank?
        raise ErrRegisterSave, 'Missing iChain header'
      end
      login = request.env['HTTP_X_USERNAME']
      email = request.env['HTTP_X_EMAIL'] if request.env['HTTP_X_EMAIL'].present?
      realname = request.env['HTTP_X_FIRSTNAME'] + ' ' + request.env['HTTP_X_LASTNAME'] if request.env['HTTP_X_LASTNAME'].present?
    end

    UnregisteredUser.register(login: login, realname: realname, email:
        email, password: password, note: note, status: status)

    # This may fail when no notification is configured. Not important, so no exception handling for now
    # IchainNotifier.deliver_approval(newuser)
    render_ok
  rescue Exception => e
    # Strip passwords from request environment and re-raise exception
    request.env['RAW_POST_DATA'] = request.env['RAW_POST_DATA'].sub(/<password>(.*)<\/password>/, '<password>STRIPPED<password>')
    raise e
  end

  def update_watchlist(user, xml)
    new_watchlist = []
    xml.get('watchlist').elements('project') do |e|
      new_watchlist << e['name']
    end

    new_watchlist.map! do |name|
      WatchedProject.find_or_create_by(project: Project.find_by_name!(name), user: user)
    end
    user.watched_projects.replace(new_watchlist)
    Rails.cache.delete(['watched_project_names', user])
  end
  private :update_watchlist

  def update_globalroles(user, xml)
    new_globalroles = []
    xml.elements('globalrole') do |e|
      new_globalroles << e.to_s
    end

    user.update_globalroles(Role.global.where(title: new_globalroles))
  end

  private :update_globalroles

  def change_my_password
    authorize @user, :update?
    # FIXME3.0: remove this function
    xml = REXML::Document.new(request.raw_post)

    logger.debug("changepasswd XML: #{request.raw_post}")

    login = xml.elements['/userchangepasswd/login'].text
    password = xml.elements['/userchangepasswd/password'].text
    login = URI.unescape(login)

    change_password(login, URI.unescape(password))
    render_ok
  end

  def change_password(login, password)
    unless User.current
      logger.debug 'No user logged in, permission to changing password denied'
      @errorcode = 401
      @summary = 'No user logged in, permission to changing password denied'
      render template: 'error', status: 401
      return
    end

    if login.blank? || password.blank?
      render_error status: 404, errorcode: 'failed to change password',
            message: 'Failed to change password: missing parameter'
      return
    end

    # change password to LDAP if LDAP is enabled
    unless ::Configuration.passwords_changable?(User.current)
      render_error status: 404, errorcode: 'change_passwd_failure',
                                message: 'LDAP passwords can not be changed in OBS. Please refer to your LDAP server to change it.'
      return
    end

    # update password in users db
    @user.password = password
    @user.save!
  end
  private :change_password

  private

  def set_user
    @user = User.find_by(login: params[:login])
  end
end
