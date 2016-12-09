module Webui::SearchHelper
  # @param [Hash] names a hash with roles as keys and an array of names as
  #         value. That is {"roletitle1" => ["name1", "name2"]}
  # @param [Symbol] type :user if the names are logins, :group if they are
  #         group names
  def search_owners_list(names, type = :user)
    return [] if names.nil? || names.empty?
    output = []
    names.each do |role, list|
      output += if type == :group
        list.map {|name| "#{name} as #{role}" }
      else
        list.map {|user| user_and_role(user, role)}
      end
    end
    output
  end
end
