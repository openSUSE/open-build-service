module Webui::SearchHelper
  # @param [Hash] names a hash with roles as keys and an array of names as
  #         value. That is {"roletitle1" => ["name1", "name2"]}
  # @param [Symbol] type :user if the names are logins, :group if they are
  #         group names
  def search_owners_list(names, type = :user)
    return [] if names.blank?
    output = []
    names.each do |role, list|
      if type == :group
        output += list.map { |name| "#{name} as #{role}" }
      else
        output += list.map { |user| user_and_role(user, role) }
      end
    end
    output
  end
end
