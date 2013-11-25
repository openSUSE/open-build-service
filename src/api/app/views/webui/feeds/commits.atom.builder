# Don't ask me why atom_feed helper does not work. Reimplementing its logic
feed_opts = { "xml:lang" => "en-US",
              "xmlns" => 'http://www.w3.org/2005/Atom' }
schema_date = "2013-11-22"

xml.feed(feed_opts) do |feed|
  feed.id "tag:#{request.host},#{schema_date}:#{request.fullpath.split(".")[0]}"
  feed.link rel: 'self', type: 'application/atom+xml', href: request.url
  title = "Commits for #{@project.name} from #{@start.strftime('%Y-%m-%d %H:%M')}"
  title += " to #{@finish.strftime('%Y-%m-%d %H:%M')}" unless @finish.nil?
  feed.title(title)
  feed.updated(@commits.first.datetime) if @commits.length > 0

  @commits.each do |commit|
    feed.entry do |entry|
      package = commit.package_name
      user = commit.user_name
      reqid = commit.bs_request_id
      datetime = commit.datetime

      title = "In #{package} at #{datetime} by #{user}"
      title += " (request #{reqid})" unless reqid.blank?
      entry.title(title)
      entry.content type: 'xhtml' do |xhtml|
        xhtml.p commit.message
        xhtml.p "Basic information:"
        xhtml.dl do |dl|
          dl.dt "Package"
          dl.dd package
          dl.dt "User"
          dl.dd user
          dl.dt "Request"
          dl.dd reqid
        end
        xhtml.p "Additional information:"
        xhtml.dl do |dl|
          commit.additional_info.each do |k,v|
            dl.dt k
            dl.dd v
          end
        end
      end

      entry.author do |author|
        author.name(user)
      end

      entry.published(datetime)
      entry.updated(datetime)
    end
  end
end
