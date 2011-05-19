xml.instruct! :xml, :version => '1.0'
xml.rss :version => '2.0' do
  xml.channel do
    xml.title "#{OBS_INSTANCE_NAME} Open Build Service Latest Updates"
    xml.description 'Latest project and package changes'
    xml.link url_for :only_path => false, :controller => 'main', :action => 'index'

    for update in @latest_updates
      xml.item do
        if update.data.name == 'package'
          xml.title "Package #{update.name} in.project #{update.project} updated"
          xml.link url_for(:only_path => false, :controller => 'project', :action => 'show', :project => update.project, :package => update.name)
        elsif update.data.name == 'project'
          xml.title "Project #{update.name} updated"
          xml.link url_for(:only_path => false, :controller => 'project', :action => 'show', :project => update.name)
        end
        xml.title update.to_s
        xml.pubDate update.updated
      end
    end
  end
end

