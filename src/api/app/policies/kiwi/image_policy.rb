class Kiwi::ImagePolicy < ApplicationPolicy
  def can_modify_package?
    record.package && user.can_modify?(record.package)
  end

  alias update? can_modify_package?
  alias destroy? can_modify_package?
end
