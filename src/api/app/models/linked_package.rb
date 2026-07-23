class LinkedPackage < Package
  def backend_writable?
    false
  end
end

# == Schema Information
#
# Table name: packages
#
#  id              :integer          not null, primary key
#  activity_index  :float(24)        default(100.0)
#  anitya_ignore   :boolean          default(FALSE), not null
#  bcntsynctag     :string(255)
#  comments_count  :integer          default(0), not null, indexed
#  delta           :boolean          default(TRUE), not null
#  description     :text(65535)
#  name            :string(200)      not null, uniquely indexed => [project_id]
#  releasename     :string(255)
#  report_bug_url  :string(8192)
#  scmsync         :string(255)
#  title           :string(255)
#  type            :string(255)      indexed
#  url             :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  develpackage_id :integer          indexed
#  kiwi_image_id   :integer          indexed
#  project_id      :integer          not null, uniquely indexed => [name]
#
# Indexes
#
#  devel_package_id_index            (develpackage_id)
#  index_packages_on_comments_count  (comments_count)
#  index_packages_on_kiwi_image_id   (kiwi_image_id)
#  index_packages_on_type            (type)
#  packages_all_index                (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...     (kiwi_image_id => kiwi_images.id)
#  packages_ibfk_3  (develpackage_id => packages.id)
#  packages_ibfk_4  (project_id => projects.id)
#
