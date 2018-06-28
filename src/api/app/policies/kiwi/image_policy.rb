class Kiwi::ImagePolicy < ApplicationPolicy
  def update?
    @record.package && @user.can_modify?(@record.package)
  end

  def destroy?
    @record.package && @user.can_modify?(@record.package)
  end
end
