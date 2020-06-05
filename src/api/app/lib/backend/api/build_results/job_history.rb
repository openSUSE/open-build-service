module Backend
  module Api
    module BuildResults
      # Class that connect to endpoints related to the jobs
      class JobHistory
        extend Backend::ConnectionHelper

        def self.for_project(project_name:, filter: { limit: nil, endtime_start: nil, endtime_end: nil, code: nil, package: nil }, raw: false)
          filter.compact!
          begin
            results = http_get(['/build/:project/_jobhistory', project_name], params: filter, expand: [:code])
          rescue Backend::Error
            return_value = raw ? '<jobhistlist />' : []
            return return_value
          end
          return results if raw

          build_local_jobhistory(jobhistory_xml: results)
        end

        def self.for_package(project_name:, package_name:, repository_name:, arch_name:, filter: { limit: nil, endtime_start: nil, endtime_end: nil, code: nil }, raw: false)
          filter.compact!

          begin
            results = http_get(['/build/:project/:repository/:arch/_jobhistory', project_name,
                                repository_name, arch_name], params: filter.merge!(package: package_name), expand: [:code])
          rescue Backend::Error
            return_value = raw ? '<jobhistlist />' : []
            return return_value
          end
          return results if raw

          build_local_jobhistory(jobhistory_xml: results, overwrite_attributes: { repository: repository_name, arch: arch_name })
        end

        def self.for_repository_and_arch(project_name:, repository_name:, arch_name:, filter: { limit: nil, endtime_start: nil, endtime_end: nil, code: nil }, raw: false)
          filter.compact!

          begin
            results = http_get(['/build/:project/:repository/:arch/_jobhistory', project_name,
                                repository_name, arch_name], params: filter, expand: [:code])
          rescue Backend::Error
            return_value = raw ? '<jobhistlist />' : []
            return return_value
          end
          return results if raw

          build_local_jobhistory(jobhistory_xml: results, overwrite_attributes: { repository: repository_name, arch: arch_name })
        end

        # We need overwrite_attributes because the backend omits repo/arch in the output when we
        # ask it for a package.
        def self.build_local_jobhistory(jobhistory_xml: '<jobhistlist></jobhistlist>', overwrite_attributes: {})
          jobhistory_hash = Xmlhash.parse(jobhistory_xml)
          local_job_history = []

          jobhistory_hash.elements('jobhist').each_with_index do |jobhistory, index|
            prev_srcmd5 = jobhistory_hash.elements('jobhist')[index - 1].try(:fetch, 'srcmd5', nil)
            attributes = { repository: jobhistory['repository'],
                           arch: jobhistory['arch'],
                           package: jobhistory['package'],
                           revision: jobhistory['rev'],
                           srcmd5: jobhistory['srcmd5'],
                           package_version: jobhistory['versrel'],
                           build_counter: jobhistory['bcnt'],
                           ready_time: jobhistory['readytime'].to_i,
                           start_time: jobhistory['starttime'].to_i,
                           end_time: jobhistory['endtime'].to_i,
                           total_time: jobhistory['endtime'].to_i - jobhistory['starttime'].to_i,
                           code: jobhistory['code'],
                           worker_id: jobhistory['workerid'],
                           host_arch: jobhistory['hostarch'],
                           reason: jobhistory['reason'],
                           verifymd5: jobhistory['verifymd5'],
                           prev_srcmd5: prev_srcmd5 }.merge!(overwrite_attributes)

            local_job_history << LocalJobHistory.new(attributes)
          end

          local_job_history.reverse
        end

        private_class_method :build_local_jobhistory
      end
    end
  end
end
