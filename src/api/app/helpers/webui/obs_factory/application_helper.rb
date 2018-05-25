module ObsFactory
  module ApplicationHelper

    # Catch some url helpers used in the OBS layout and forward them to
    # the main application
    %w(home_path user_tasks_path root_path project_show_path search_path user_show_url user_show_path
       user_register_user_path news_feed_path project_toggle_watch_path
       project_list_public_path monitor_path projects_path new_project_path
       user_rss_notifications_url session_new_path session_create_path session_destroy_path).each do |m|
      define_method(m) do |*args|
        main_app.send(m, *args)
      end
    end

    def openqa_links_helper
      OpenqaJob.openqa_links_url
    end

  end
end
