# frozen_string_literal: true
xml.rss version: '2.0' do
  xml.channel do
    xml.title "#{@configuration['title']} Latest Updates"
    xml.description 'Latest project and package changes'
    xml.link url_for only_path: false, controller: :main, action: :index

    @latest_updates.each do |element|
      xml.item do
        if element[1] == :package
          xml.title "Package #{element[2]} in.project #{element[3]} updated"
          xml.link url_for(only_path: false, controller: :package, action: :show, project: element[3], package: element[2])
        else
          xml.title "Project #{element[1]} updated"
          xml.link url_for(only_path: false, controller: :project, action: :show, project: element[1])
        end
        xml.pubDate element[0]
      end
    end
  end
end
