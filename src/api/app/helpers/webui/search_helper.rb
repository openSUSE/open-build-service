# TODO: bento_only
module Webui::SearchHelper
  # @param [Hash] names a hash with roles as keys and an array of records (User or Group) as
  #         value. That is {"roletitle1" => [Record1, Record2]}
  # @param [Symbol] type :user if the names are logins, :group if they are
  #         group names
  def search_owners_list(records, type = :user)
    return [] if records.blank?
    output = []
    records.each do |role, list|
      if type == :group
        output += list.map { |name| "#{name} as #{role}" }
      else
        output += list.map { |user| user_and_role(user.login, role) }
      end
    end
    output
  end
end
