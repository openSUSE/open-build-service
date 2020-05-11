module ProjectSphinx
  def attribs_attrib_type_ids
    attribs.pluck(:attrib_type_id)
  end

  def packages_package_issues_ids
    packages.map(&:package_issues_ids).flatten.uniq
  end

  def linked_projects?
    linking_to.exists?
  end

  def devel_packages?
    packages.joins(:develpackages).exists?
  end

  def linked_count
    linked_by.count
  end

  def last_package_updated_at
    packages.maximum(:updated_at)
  end

  def activity_index
    packages.where(updated_at: last_package_updated_at).maximum(:activity_index)
  end
end
