module PackageSphinx
  def attribs_attrib_type_ids
    attribs.pluck(:attrib_type_id)
  end

  def package_issues_ids
    package_issues.pluck(:issue_id)
  end

  def devel_packages?
    develpackages.exists?
  end

  def linked_packages?
    BackendPackage.exists?(package_id: id)
  end

  def linked_count
    linking_packages.count
  end
end
