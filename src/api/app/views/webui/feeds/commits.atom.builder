# FIXME: atom_feed helper bails out with
# ActionView::Template::Error (A document may not have multiple root nodes.)
# Reimplementing its logic...
feed_opts = { 'xml:lang' => 'en-US',
              'xmlns' => 'http://www.w3.org/2005/Atom' }
schema_date = '2013-11-22'
obs_host = URI.parse(Configuration.obs_url).host

xml.feed(feed_opts) do |feed|
  feed.id "tag:#{request.host},#{schema_date}:#{request.fullpath.split('.')[0]}"
  feed.link rel: 'self', type: 'application/atom+xml', href: request.url
  title = "Commits for #{@project.name}"
  feed.title(title)
  feed.updated(@commits.first.datetime.iso8601) if @commits.present?

  @commits.each do |commit|
    feed.entry do |entry|
      package = commit.package_name
      user = commit.user_name
      reqid = BsRequest.find(commit.bs_request_id).number if commit.bs_request_id
      datetime = commit.datetime
      package_url = url_for(only_path: false, controller: 'package', action: 'rdiff', project: @project.name,
                            package: package, rev: commit.additional_info['rev'], linkrev: 'base')
      request_url = request_show_url(reqid) if reqid.present?

      if @terse
        entry.title("New commit in #{package}")
        content = "Revision #{commit.additional_info['rev']}"
        content += " via request #{reqid}" if reqid.present?
        content += ' via service' if commit.message == 'trigger service run'
        entry.content(content, type: 'text')
      else
        title = "New commit in #{package} (#{commit.additional_info['rev']}) by #{user}"
        title += " (via #{reqid})" if reqid.present?
        entry.title(title)
        entry.content type: 'xhtml' do |xhtml|
          xhtml.div do |div|
            div.p commit.message
            div.p 'Basic information:'
            div.dl do |dl|
              dl.dt 'Package'
              dl.dd do |dd|
                dd.a package, href: package_url
              end
              dl.dt 'User'
              dl.dd user
              if reqid
                dl.dt 'Request'
                dl.dd do |dd|
                  dd.a reqid, href: request_url
                end
              end
            end
            div.p 'Additional information:'
            div.dl do |dl|
              commit.additional_info.each do |k, v|
                dl.dt k
                dl.dd v
              end
            end
          end
        end
      end

      entry.author do |author|
        author.name(user)
      end

      entry.published(datetime.iso8601)
      entry.id("tag:#{obs_host},2013-12-01:#{@project.name}/#{commit.id}")
      entry_url = reqid.present? ? request_url : package_url
      entry.link(href: entry_url)
      entry.updated(datetime.iso8601)
    end
  end
end
