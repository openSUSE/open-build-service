# frozen_string_literal: true
xml.person do
  xml.login @render_user.login
  xml.email @render_user.email
  xml.realname @render_user.realname

  if @render_user.watched_projects.count > 0
    xml.watchlist do
      @render_user.watched_projects.each do |wp|
        xml.project name: wp.name
      end
    end
  end
end
