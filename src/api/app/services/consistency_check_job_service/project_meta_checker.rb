module ConsistencyCheckJobService
  class ProjectMetaChecker
    attr_reader :errors

    def initialize(project)
      @project = project
      @errors = []
    end

    def call
      @errors << "Project meta is different in backend for #{@project.name}\n#{diff}" if diff.present?
    end

    private

    def diff
      hash_diff(frontend_meta, backend_meta)
    end

    def frontend_meta
      Xmlhash.parse(@project.to_axml)
    end

    def backend_meta
      Xmlhash.parse(Backend::Api::Sources::Project.meta(@project))
    end

    def hash_diff(a, b)
      # ignore the order inside of the hash
      (a.keys | b.keys).sort!.each_with_object({}) do |diff, k|
        a_ = a[k]
        b_ = b[k]
        # we need to ignore the ordering in some cases
        # old xml generator wrote them in a different order
        # but in other cases the order of elements matters
        if k == 'person' && a_.is_a?(Array)
          a_ = a_.map { |i| "#{i['userid']}/#{i['role']}" }.sort!
          b_ = b_.map { |i| "#{i['userid']}/#{i['role']}" }.sort!
        end
        if k == 'group' && a_.is_a?(Array)
          a_ = a_.map { |i| "#{i['groupid']}/#{i['role']}" }.sort!
          b_ = b_.map { |i| "#{i['groupid']}/#{i['role']}" }.sort!
        end
        if a_ != b_
          if a[k].class == Hash && b[k].class == Hash
            diff[k] = hash_diff(a[k], b[k])
          else
            diff[k] = [a[k], b[k]]
          end
        end
        diff
      end
    end
  end
end
