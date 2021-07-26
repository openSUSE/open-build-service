# frozen_string_literal: true

class DeleteStaticPermissionSetDownloadCounters < ActiveRecord::Migration[6.1]
  def up
    StaticPermission.find_by(title: 'set_download_counters').try(:destroy)
  end

  def down
    StaticPermission.create(title: 'set_download_counters')
  end
end
