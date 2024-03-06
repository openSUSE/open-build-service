class Webui::UserPolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, { ensure_logged_in: true }.merge(opts))
  end

  # This is a stub: right now the authorization logic lives in Webui::UsersController.
  # TODO: move here the authorization logic from Webui::UsersController.
  %i[index? edit? destroy? change_password? edit_account?].each do |action|
    define_method action do
      true
    end
  end

  def update?
    configuration = ::Configuration.first

    return false unless configuration.accounts_editable?(record)
    return true if user.is_admin? || user == record

    false
  end

  def block_commenting?
    return true if user.is_admin? || user.is_moderator?

    false
  end
end
