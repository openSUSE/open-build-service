class PackagesFinder
  def initialize(relation = Package.all)
    @relation = relation
  end

  def by_package_and_project(package, project)
    @relation.where(name: package, projects: { name: project }).includes(:project)
  end

  def find_by_attribute_type(attrib_type, package = nil)
    # One sql statement is faster than a ruby loop
    # attribute match in package or project
    sql = build_sql_find_by_attribute(package)
    finder_arguments = if package
                         [sql, attrib_type.id.to_s, attrib_type.id.to_s, package]
                       else
                         [sql, attrib_type.id.to_s, attrib_type.id.to_s]
                       end
    find_package(finder_arguments)
  end

  def find_by_attribute_type_and_value(attrib_type, value, package = nil)
    # One sql statement is faster than a ruby loop
    sql = build_sql_find_by_attribute_and_value(package)
    finder_arguments = if package
                         [sql, attrib_type.id.to_s, value.to_s, package]
                       else
                         [sql, attrib_type.id.to_s, value.to_s]
                       end
    find_package(finder_arguments)
  end

  def forbidden_packages
    @relation.where(project_id: Relationship.forbidden_project_ids)
  end

  private

  def find_package(args)
    Package.find_by_sql(args).keep_if { |p| p.project.check_access? }
  end

  def base_query
    <<-END_SQL
      SELECT pack.* FROM packages pack
      LEFT OUTER JOIN attribs attr ON pack.id = attr.package_id
    END_SQL
  end

  def find_by_attribute
    <<-END_SQL
      LEFT OUTER JOIN attribs attrprj ON pack.project_id = attrprj.project_id
      WHERE ( attr.attrib_type_id = ? or attrprj.attrib_type_id = ? )
    END_SQL
  end

  def build_sql_find_by_attribute(package = nil)
    if package
      "#{base_query}#{find_by_attribute} AND pack.name = ? GROUP by pack.id"
    else
      "#{base_query}#{find_by_attribute} GROUP by pack.id"
    end
  end

  def find_by_attribute_and_value
    <<-END_SQL
      LEFT OUTER JOIN attrib_values val ON attr.id = val.attrib_id
      WHERE attr.attrib_type_id = ? AND val.value = ?
    END_SQL
  end

  def build_sql_find_by_attribute_and_value(package = nil)
    if package
      "#{base_query}#{find_by_attribute_and_value} AND pack.name = ?"
    else
      "#{base_query}#{find_by_attribute_and_value} GROUP by pack.id"
    end
  end
end
