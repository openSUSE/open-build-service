# this worker would test thread issues that were discussed before
require "net/http"
class RssWorker < BackgrounDRb::MetaWorker
  set_worker_name :rss_worker
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
  end

  # method would fetch supplied urls in a thread
  def fetch_url(url)
    puts "fetching url #{url}"
    thread_pool.defer(:scrap_things,url)
  end

  def scrap_things url
    begin
      data = Net::HTTP.get(url,"/")
      File.open("#{RAILS_ROOT}/log/pages.txt","w") do |fl|
        fl.puts(data)
      end
    rescue
      logger.info "Error downloading page"
    end
  end
end

