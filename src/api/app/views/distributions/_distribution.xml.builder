builder.distribution(vendor: distribution['vendor'], version: distribution['version'], id: distribution['id']) do
  builder.name(distribution['name'])
  builder.project(distribution['project'])
  builder.reponame(distribution['reponame'])
  builder.repository(distribution['repository'])
  builder.link(distribution['link'])
  distribution['icons'].each do |i|
    attr = { url: i['url'] }
    attr[:width] = i['width'] if i['width'].present?
    attr[:height] = i['height'] if i['height'].present?
    builder.icon(attr)
  end
  distribution['architectures'].each do |architecture|
    builder.architecture(architecture.to_s)
  end
end
