# frozen_string_literal: true

class GroupController < ApplicationController
  include ValidationHelper

  validate_action groupinfo: { method: :get, response: :group }
  validate_action groupinfo: { method: :put, request: :group, response: :status }
  validate_action groupinfo: { method: :delete, response: :status }

  # raise an exception if authorize has not yet been called.
  after_action :verify_authorized, except: [:index, :show]

  rescue_from Pundit::NotAuthorizedError do |exception|
    pundit_action = case exception.query.to_s
                    when 'index?' then 'list'
                    when 'show?' then 'view'
                    when 'create?' then 'create'
                    when 'new?' then 'create'
                    when 'update?' then 'update'
                    when 'destroy?' then 'delete'
                    else exception.query
    end

    render_error status: 403, errorcode: "No permission to #{pundit_action} group"
  end

  def index
    if params[:login]
      user = User.find_by_login!(params[:login])
      @list = user.groups
    else
      @list = Group.all
    end
    @list = @list.where('title LIKE ?', "#{params[:prefix]}%") if params[:prefix].present?
  end

  # DELETE for removing it
  def delete
    group = Group.find_by_title!(params[:title])
    authorize group, :destroy?
    group.destroy
    render_ok
  end

  # GET for showing the group
  def show
    @group = Group.find_by_title!(params[:title])
  end

  # PUT for rewriting it completely including defined user list.
  def update
    group = Group.find_by_title(params[:title])
    if group.nil?
      authorize Group, :create?
      group = Group.create(title: params[:title])
    end
    authorize group, :update?

    xmlhash = Xmlhash.parse(request.raw_post)
    raise InvalidParameterError, 'group name from path and xml mismatch' unless group.title == xmlhash.value('title')

    group.update_from_xml(xmlhash)
    group.save!

    render_ok
  end

  # POST for editing it, adding or remove users
  def command
    group = Group.find_by_title!(URI.unescape(params[:title]))
    authorize group, :update?

    user = User.find_by_login!(params[:userid]) if params[:userid]

    if params[:cmd] == 'add_user'
      group.add_user user
    elsif params[:cmd] == 'remove_user'
      group.remove_user user
    elsif params[:cmd] == 'set_email'
      group.set_email params[:email]
    else
      raise UnknownCommandError, 'cmd must be set to add_user or remove_user'
    end

    render_ok
  end
end
