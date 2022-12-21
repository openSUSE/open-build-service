class Webui::UserPolicy < ApplicationPolicy
  def initialize(user, record, opts = {})
    super(user, record, { ensure_logged_in: true }.merge(opts))
  end

  # This is a stub: right now the authorization logic lives in Webui::UsersController.
  # TODO: move here the authorization logic from Webui::UsersController.
  [:index?, :edit?, :destroy?, :update?, :change_password?, :edit_account?].each do |action|
    define_method action do
      true
    end
  end
end
