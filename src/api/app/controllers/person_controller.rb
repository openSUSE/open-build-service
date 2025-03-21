require 'xmlhash'

class PersonController < ApplicationController
  validate_action grouplist: { method: :get, response: :directory }
  validate_action register: { method: :put, response: :status }
  validate_action register: { method: :post, response: :status }

  skip_before_action :extract_user, only: %i[command register]
  skip_before_action :require_login, only: %i[command register]

  before_action :set_user, only: %i[post_userinfo change_my_password watchlist put_watchlist]
  before_action :user_permission_check, only: [:post_userinfo]
  before_action :require_admin, only: [:post_userinfo], if: -> { %w[delete lock].include?(params[:cmd]) }

  def show
    @list = if params[:prefix]
              User.where('login LIKE ?', "#{params[:prefix]}%")
            elsif params[:confirmed]
              User.confirmed
            else
              User.not_deleted
            end
  end

  def command
    if params[:cmd] == 'register'
      internal_register
      return
    end
    raise UnknownCommandError, "Allowed command is 'register'"
  end

  def userinfo
    user = User.find_by_login!(params[:login])

    if user == User.session
      logger.debug "Generating user info for logged in user #{User.session.login}"
      render xml: User.session.render_axml(watchlist: true)
    else
      logger.debug "Generating for user from parameter #{user.login}"
      render xml: user.render_axml(watchlist: User.admin_session?)
    end
  end

  def post_userinfo
    if params[:cmd] == 'change_password'
      login ||= User.session.login
      password = request.raw_post.to_s.chomp
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
      user = User.find_by_login!(params[:login])
      user.lock!
      render_ok
      return
    end
    if params[:cmd] == 'delete'
      # maybe we should allow the users to delete themself?
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

    unless ::Configuration.accounts_editable?
      render_error(status: 403, errorcode: 'change_userinfo_no_permission',
                   message: "no permission to change userinfo for user #{user.login}")
      return
    end

    if user
      unless user.login == User.session.login || User.admin_session?
        logger.debug 'User has no permission to change userinfo'
        render_error(status: 403, errorcode: 'change_userinfo_no_permission',
                     message: "no permission to change userinfo for user #{user.login}") && return
      end
    elsif User.admin_session?
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
    if User.admin_session?
      # only admin is allowed to change these, ignore for others
      user.state = xml.value('state')
      update_globalroles(user, xml)
      user.update(ignore_auth_services: xml.value('ignore_auth_services').to_s.casecmp?('true'))

      if xml['owner']
        user.state = :subaccount
        user.owner = User.find_by_login!(xml['owner']['userid'])
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

  def watchlist
    if @user
      authorize @user, :update?

      render xml: @user.render_axml(render_watchlist_only: true)
    else
      @errorcode = 404
      @summary = 'Requested non-existing user'
      render_error(status: @errorcode)
    end
  end

  def put_watchlist
    if @user
      authorize @user, :update?
    else
      @errorcode = 404
      @summary = 'Requested non-existing user'
      render_error(status: @errorcode) && return
    end

    xml = Xmlhash.parse(request.raw_post)
    ActiveRecord::Base.transaction do
      update_watchlist(@user, xml)
    end
    render_ok
  end

  def grouplist
    user = User.find_by_login!(params[:login])
    @list = user.list_groups
  end

  def register
    # FIXME: 3.0, to be removed
    internal_register
  end

  class ErrRegisterSave < APIError
  end

  def internal_register
    xml = REXML::Document.new(request.raw_post)

    logger.debug("register XML: #{request.raw_post}")

    login = xml.elements['/unregisteredperson/login'].text
    realname = xml.elements['/unregisteredperson/realname'].text
    email = xml.elements['/unregisteredperson/email'].text
    password = xml.elements['/unregisteredperson/password'].text
    note = xml.elements['/unregisteredperson/note'].text if xml.elements['/unregisteredperson/note']
    status = xml.elements['/unregisteredperson/state'].text if xml.elements['/unregisteredperson/status']

    if ::Configuration.proxy_auth_mode_enabled?
      raise ErrRegisterSave, 'Missing iChain header' if request.env['HTTP_X_USERNAME'].blank?

      login = request.env['HTTP_X_USERNAME']
      email = request.env['HTTP_X_EMAIL'] if request.env['HTTP_X_EMAIL'].present?
      realname = "#{request.env['HTTP_X_FIRSTNAME']} #{request.env['HTTP_X_LASTNAME']}" if request.env['HTTP_X_LASTNAME'].present?
    end

    UnregisteredUser.register(login: login, realname: realname, email:
        email, password: password, note: note, status: status)

    render_ok
  rescue StandardError => e
    # Strip passwords from request environment and re-raise exception
    request.env['RAW_POST_DATA'] = request.env['RAW_POST_DATA'].sub(%r{<password>(.*)</password>}, '<password>STRIPPED<password>')
    raise e
  end

  def change_my_password
    authorize @user, :update?
    # FIXME3.0: remove this function
    xml = REXML::Document.new(request.raw_post)

    logger.debug("changepasswd XML: #{request.raw_post}")

    login = xml.elements['/userchangepasswd/login'].text
    password = xml.elements['/userchangepasswd/password'].text
    login = CGI.unescape(login)

    change_password(login, CGI.unescape(password))
    render_ok
  end

  private

  def set_user
    @user = User.find_by(login: params[:login])
  end

  def user_permission_check
    authorize @user, :update?

    login = params[:login]
    # just for permission checking
    User.find_by_login!(login)
  end

  def update_watchlist(user, xml)
    if xml.get('watchlist').empty?
      projects = [xml.get('project')].flatten
      packages = [xml.get('package')].flatten
      requests = [xml.get('request')].flatten
    else
      projects = xml.get('watchlist').elements('project')
      packages = xml.get('watchlist').elements('package')
      requests = xml.get('watchlist').elements('request')
    end

    watchables = []
    watchables << projects.map { |proj| Project.find_by(name: proj['name']) }
    watchables << packages.map { |pkg| Package.find_by_project_and_name(pkg['project'], pkg['name']) }
    watchables << requests.map { |req| BsRequest.find_by(number: req['number']) }
    user.watched_items.clear
    watchables.flatten.compact.each do |item|
      user.watched_items.create!(watchable: item)
    end
  end

  def update_globalroles(user, xml)
    new_globalroles = []
    xml.elements('globalrole') do |e|
      new_globalroles << e.to_s
    end

    user.update_globalroles(Role.global.where(title: new_globalroles))
  end

  def change_password(login, password)
    if login.blank? || password.blank?
      render_error status: 404, errorcode: 'failed to change password',
                   message: 'Failed to change password: missing parameter'
      return
    end

    # change password to LDAP if LDAP is enabled
    unless ::Configuration.passwords_changable?
      render_error status: 404, errorcode: 'change_passwd_failure',
                   message: 'LDAP passwords can not be changed in OBS. Please refer to your LDAP server to change it.'
      return
    end

    # update password in users db
    @user.password = password
    @user.save!
  end
end
