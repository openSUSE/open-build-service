abies = @an.attrib_namespace_modifiable_bies.includes([:user, :group])
if abies.length > 0
  xml.namespace(:name => @an.name) do |an|
    abies.each do |mod_rule|
      p = {}
      p[:user] = mod_rule.user.login if mod_rule.user
      p[:group] = mod_rule.group.title if mod_rule.group
      an.modifiable_by(p)
    end
  end
else
  xml.namespace(:name => @an.name)
end
