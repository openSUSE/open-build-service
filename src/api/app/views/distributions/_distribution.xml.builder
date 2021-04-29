builder.distribution(vendor: distribution.vendor, version: distribution.version, id: distribution.id) do
  builder.name(distribution.name)
  builder.project(distribution.project)
  builder.reponame(distribution.reponame)
  builder.repository(distribution.repository)
  builder.link(distribution.link)
  distribution.icons.each do |icon|
    attr = { url: icon.url }
    attr[:width] = icon.width if icon.width.present?
    attr[:height] = icon.height if icon.height.present?
    builder.icon(attr)
  end
  distribution.architectures.each do |architecture|
    builder.architecture(architecture.name)
  end
end
