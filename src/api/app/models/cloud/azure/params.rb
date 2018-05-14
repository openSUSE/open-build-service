module Cloud
  module Azure
    class Params
      include ActiveModel::Validations
      include ActiveModel::Model

      attr_accessor :image_name, :application_id, :application_key, :subscription, :container, :storage_account, :resource_group

      validates :image_name, presence: true, length: { minimum: 2, maximum: 63 },
                format: { with: /\A[[:alnum:]]([\w\.-]*\w)?\z/, message: 'not a valid format' }
      validates :subscription, presence: true, length: { minimum: 3 }
      validates :container, presence: true, length: { minimum: 3, maximum: 63 },
                format: { with: /\A[-a-z0-9]+\z/, message: 'not a valid format' }
      validates :storage_account, presence: true, length: { minimum: 3, maximum: 24 },
                format: { with: /\A[a-z0-9]+\z/, message: 'not a valid format' }
      validates :resource_group, presence: true, length: { minimum: 1, maximum: 90 },
                format: { with: /\A[-\w\.]*[-\w]\z/, message: 'not a valid format' }

      def self.build(params)
        new(params.slice(:image_name, :application_id, :application_key, :subscription, :container, :storage_account, :resource_group))
      end
    end
  end
end
