module Backend
  module Api
    module Cloud
      extend Backend::ConnectionHelper
      # Triggers a cloud upload job
      # @return [String]
      def self.upload(params)
        data = params.slice(:region, :virtualization_type, :ami_name)
        user = params[:user]
        params = params.except(:region, :virtualization_type, :ami_name).merge(user: user.login, target: params[:target])
        data = user.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(data).to_json
        post('/cloudupload', params: params, data: data)
      end

      # Returns the status of the cloud upload jobs of a user
      # @return [String]
      def self.status(user)
        get('/cloudupload', params: { name: user.upload_jobs.pluck(:job_id) }, expand: [:name])
      end

      # Returns the log file of the cloud upload job
      # @return [String]
      def self.log(id)
        get(['/cloudupload/:id/_log', id], params: { nostream: 1, start: 0 })
      end

      # Destroys (killing the process) the upload job.
      # The backend will not delete the log files etc for history reasons.
      # It will return the status of the job or raise an exception.
      # @return [String]
      def self.destroy(id)
        post(['/cloudupload/:id', id], params: { cmd: :kill })
      end
    end
  end
end
