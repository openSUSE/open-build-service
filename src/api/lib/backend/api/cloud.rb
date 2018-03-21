module Backend
  module Api
    module Cloud
      extend Backend::ConnectionHelper
      # Triggers a cloud upload job
      # @return [String]
      def self.upload(params)
        data = params.slice(:region, :ami_name, :vpc_subnet_id)
        user = params[:user]
        params = params.except(:region, :ami_name, :vpc_subnet_id).merge(user: user.login, target: params[:target])
        data = user.ec2_configuration.upload_parameters.merge(data).to_json
        http_post('/cloudupload', params: params, data: data)
      end

      # Returns the backend data associated to a given list of cloud upload job ids
      # @return [String]
      def self.upload_jobs(job_ids = [])
        return "<clouduploadjoblist>\n</clouduploadjoblist>\n" if job_ids.empty?
        http_get('/cloudupload', params: { name: job_ids }, expand: [:name])
      end

      # Returns the log file of the cloud upload job
      # @return [String]
      def self.log(id)
        http_get(['/cloudupload/:id/_log', id], params: { nostream: 1, start: 0 })
      end

      # Destroys (killing the process) the upload job.
      # The backend will not delete the log files etc for history reasons.
      # It will return the status of the job or raise an exception.
      # @return [String]
      def self.destroy(id)
        http_post(['/cloudupload/:id', id], params: { cmd: :kill })
      end
    end
  end
end
