module Backend
  module Api
    module Cloud
      extend Backend::ConnectionHelper
      # Triggers a cloud upload job
      # @return [String]
      def self.upload(params)
        user = params[:user]
        case params[:target]
        when 'ec2'
          param_names = [:region, :ami_name, :vpc_subnet_id]
          upload_parameters = user.ec2_configuration.upload_parameters
        when 'azure'
          param_names = [
            :image_name, :application_id, :application_key, :subscription, :container, :storage_account, :resource_group
          ]
          upload_parameters = user.azure_configuration.upload_parameters
        end
        data = params.slice(*param_names)
        params = params.except(*param_names).merge(user: user.login, target: params[:target])
        json = upload_parameters.merge(data).to_json
        http_post('/cloudupload', params: params, data: json)
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

      # Retrieves the public key of the cloud upload server. The public key is being used
      # to encrypt sensitive data that should not be stored in the frontend's database.
      #
      # @return [String]
      def self.public_key
        http_get('/cloudupload/_pubkey')
      end
    end
  end
end
