p = {}
p[:name] = @at.name
p[:namespace] = @at.attrib_namespace.name
xml.definition(p) do |attr|

  if @at.description
    attr.description @at.description
  end

  if @at.default_values.present?
    attr.default do |default|
      @at.default_values.each do |def_val|
        default.value def_val.value
      end
    end
  end

  if @at.allowed_values.present?
    attr.allowed do |allowed|
      @at.allowed_values.each do |all_val|
        allowed.value all_val.value
      end
    end
  end

  if @at.value_count
    attr.count @at.value_count
  end

  if @at.issue_list
    attr.issue_list
  end

  abies = @at.attrib_type_modifiable_bies.includes(:user, :group, :role)
  if abies.present?
    abies.each do |mod_rule|
      p = {}
      p[:user] = mod_rule.user.login if mod_rule.user
      p[:group] = mod_rule.group.title if mod_rule.group
      p[:role] = mod_rule.role.title if mod_rule.role
      attr.modifiable_by(p)
    end
  end
end
