module Webui::SearchHelper

  # @param [Hash] users a hash with roles as keys and an array of logins as
  #         value. That is {"roletitle1" => ["login1", "login2"]}
  def search_users_list(users)
    return "" if users.nil? || users.empty?
    output = []
    users.each do |role, logins|
      output += logins.map {|user| user_and_role(user, role)}
    end
    output.join("<br />").html_safe
  end

end
