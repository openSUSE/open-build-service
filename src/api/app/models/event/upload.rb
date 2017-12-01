module Event
  class Upload < Package
    self.description = 'Package sources were uploaded'
    payload_keys :project, :package, :comment, :filename, :requestid, :target, :user
    after_create_commit :send_to_bus

    def self.message_bus_routing_key
      "#{Configuration.amqp_namespace}.package.upload"
    end
  end
end

# == Schema Information
#
# Table name: packages
#
#  id              :integer          not null, primary key
#  project_id      :integer          not null, indexed => [name]
#  name            :string(200)      not null, indexed => [project_id]
#  title           :string(255)
#  description     :text(65535)
#  created_at      :datetime
#  updated_at      :datetime         indexed
#  url             :string(255)
#  activity_index  :float(24)        default(100.0)
#  bcntsynctag     :string(255)
#  develpackage_id :integer          indexed
#  delta           :boolean          default(TRUE), not null
#  releasename     :string(255)
#  kiwi_image_id   :integer          indexed
#
# Indexes
#
#  devel_package_id_index           (develpackage_id)
#  index_packages_on_kiwi_image_id  (kiwi_image_id)
#  packages_all_index               (project_id,name) UNIQUE
#  updated_at_index                 (updated_at)
#
# Foreign Keys
#
#  fk_rails_...     (kiwi_image_id => kiwi_images.id)
#  packages_ibfk_3  (develpackage_id => packages.id)
#  packages_ibfk_4  (project_id => projects.id)
#
