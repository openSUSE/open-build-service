class LocalJobHistory
  include ActiveModel::Model
  attr_accessor :repository,
                :arch,
                :package,
                :revision,
                :srcmd5,
                :package_version,
                :build_counter,
                :ready_time,
                :start_time,
                :end_time,
                :total_time,
                :code,
                :worker_id,
                :host_arch,
                :reason,
                :verifymd5,
                :prev_srcmd5
end
