module HasMobileViewsHelper

  # Helper to render the link to get from the mobile version to the normal one or vice-versa
  #   opts[:switch_to_normal_text] can be used to override the text for the "switch to normal" case
  #   opts[:switch_to_mobile_text] can be used to override the text for the "switch to mobile" case
  #   opts[:html] will we passed to the link_to helper
  def switch_view_mode_link opts = {}
    if session[:mobile_view]
      text = opts[:switch_to_normal_text] || "Switch to normal version"
      link_to text, params.update(:force_view => 'normal'), opts[:html]
    else
      text = opts[:switch_to_normal_text] || "Switch to mobile version"
      link_to text, params.update(:force_view => 'mobile'), opts[:html]
    end
  end
end

ActionView::Base.send(:include, HasMobileViewsHelper)