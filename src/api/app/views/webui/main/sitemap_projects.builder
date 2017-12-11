# rubocop:disable Metrics/LineLength
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation" => "http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd") do
  # rubocop:enable Metrics/LineLength

  xml.url do
    xml.loc url_for controller: :main, action: :index, only_path: false
    xml.priority 1.0
  end

  projecturl = url_for(controller: :project, action: :show, project: 'REPLACEIT', only_path: false)
  @projects.each do |p|
    xml.url do
      xml.loc projecturl.gsub('REPLACEIT', p)
      xml.priority 0.9
    end
  end
end
