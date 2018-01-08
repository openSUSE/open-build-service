module Backend
  module Api
    module Cloud
      extend Backend::ConnectionHelper
      # Triggers a cloud upload job
      # @return [String]
      def self.upload(user, params, target_name = 'ec2')
        region = params.delete(:region)
        data = user.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(region: region).to_json
        post('/cloudupload', params: params.merge(user: user.login, target: target_name), data: data)
      end

      # Returns the status of the cloud upload jobs of a user
      # @return [String]
      def self.status(user)
        get('/cloudupload', params: { name: user.upload_jobs.pluck(:job_id) }, expand: [:name])
      end
    end
  end
end
