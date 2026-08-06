class LinkedPackagePolicy < PackagePolicy
  def update?
    false
  end

  def save_meta_update?
    false
  end

  def destroy?
    false
  end

  def unlock?
    false
  end
end
