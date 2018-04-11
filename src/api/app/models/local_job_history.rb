# frozen_string_literal: true

class LocalJobHistory
  include ActiveModel::Model
  attr_accessor :revision,
                :build_counter,
                :worker_id,
                :host_arch,
                :reason,
                :ready_time,
                :start_time,
                :end_time,
                :total_time,
                :code,
                :srcmd5,
                :verifymd5,
                :prev_srcmd5
end
