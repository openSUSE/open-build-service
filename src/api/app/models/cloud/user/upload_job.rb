module Cloud
  module User
    class UploadJob < ApplicationRecord
      belongs_to :user, required: true, class_name: '::User'

      validates :job_id, presence: true, uniqueness: true

      def self.table_name_prefix
        'cloud_user_'
      end
    end
  end
end

# == Schema Information
#
# Table name: cloud_user_upload_jobs
#
#  id         :integer          not null, primary key
#  user_id    :integer          indexed
#  job_id     :integer          indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_cloud_user_upload_jobs_on_job_id   (job_id) UNIQUE
#  index_cloud_user_upload_jobs_on_user_id  (user_id)
#
