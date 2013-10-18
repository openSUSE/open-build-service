xml.rss :version => '2.0' do
  xml.channel do
    xml.title "#{@configuration['title']} News"
    xml.description 'Recent news'
    xml.link url_for :only_path => false, :controller => 'main', :action => 'index'

    for message in @news
      xml.item do
        xml.title message.to_s 
        xml.pubDate message.created_at
        xml.author message.value(:user)
        xml.link url_for :only_path => false, :controller => 'main', :action => 'index'
      end
    end
  end
end
