module Event
  class DeleteProject < Project
    self.description = 'Project was deleted'
    payload_keys :comment, :requestid, :sender
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.project.delete"
    end
  end
end

# == Schema Information
#
# Table name: projects
#
#  id              :integer          not null, primary key
#  name            :string(200)      not null, indexed
#  title           :string(255)
#  description     :text(65535)
#  created_at      :datetime
#  updated_at      :datetime         indexed
#  remoteurl       :string(255)
#  remoteproject   :string(255)
#  develproject_id :integer          indexed
#  delta           :boolean          default(TRUE), not null
#  kind            :string(20)       default("standard")
#  url             :string(255)
#
# Indexes
#
#  devel_project_id_index  (develproject_id)
#  projects_name_index     (name) UNIQUE
#  updated_at_index        (updated_at)
#
