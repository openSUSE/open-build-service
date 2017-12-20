module Backend
  module Api
    module Cloud
      extend Backend::ConnectionHelper
      # Triggers a cloud upload job
      # @return [String]
      def self.upload(user, params, target_name = 'ec2')
        region = params.delete(:region)
        data = user.ec2_configuration.attributes.except('id', 'created_at', 'updated_at').merge(region: region).to_json
        post(['/cloudupload'], params: params.merge(user: user.login, target: target_name), data: data)
      end

      # Returns the status of a cloud upload job
      # @return [String]
      def self.status(job_id)
        get(['/cloudupload', job_id])
      end
    end
  end
end
