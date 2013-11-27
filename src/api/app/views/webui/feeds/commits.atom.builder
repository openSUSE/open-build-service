# Don't ask me why atom_feed helper does not work. Reimplementing its logic
feed_opts = { "xml:lang" => "en-US",
              "xmlns" => 'http://www.w3.org/2005/Atom' }
schema_date = "2013-11-22"

xml.feed(feed_opts) do |feed|
  feed.id "tag:#{request.host},#{schema_date}:#{request.fullpath.split(".")[0]}"
  feed.link rel: 'self', type: 'application/atom+xml', href: request.url
  title = "Commits for #{@project.name}"
  feed.title(title)
  feed.updated(@commits.first.datetime.iso8601) if @commits.length > 0

  @commits.each do |commit|
    feed.entry do |entry|
      package = commit.package_name
      user = commit.user_name
      reqid = commit.bs_request_id
      datetime = commit.datetime

      title = "In #{package}"
      title += " (request #{reqid})" unless reqid.blank?
      entry.title(title)
      entry.content type: 'xhtml' do |xhtml|
        xhtml.div do |div|
          div.p commit.message
          div.p "Basic information:"
          div.dl do |dl|
            dl.dt "Package"
            dl.dd do |dd|
              dd.a package, href: url_for(:only_path => false, :controller => 'package', :action  => 'revisions', :project => @project.name, :package => package, :format => :html, :showall => 1)
            end
            dl.dt "User"
            dl.dd user
            dl.dt "Request"
            if reqid
              dl.dd do |dd|
                dd.a reqid, href: request_show_url(reqid)
              end
            else
              dl.dd reqid
            end
          end
          div.p "Additional information:"
          div.dl do |dl|
            commit.additional_info.each do |k,v|
              dl.dt k
              dl.dd v
            end
          end
        end
      end

      entry.author do |author|
        author.name(user)
      end

      entry.published(datetime.iso8601)
      entry.updated(datetime.iso8601)
    end
  end
end
