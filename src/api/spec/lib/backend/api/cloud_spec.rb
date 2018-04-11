# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Backend::Api::Cloud do
  context '#upload' do
    let(:user) { create(:confirmed_user) }
    let!(:ec2_configuration) { create(:ec2_configuration, user: user) }

    it 'crafts a correct backend request' do
      # rubocop:disable RSpec/MessageSpies
      expect(Backend::Api::Cloud).to receive(:http_post).with(
        '/cloudupload',
        params: {
          user:   user.login,
          target: 'ec2'
        },
        data: ec2_configuration.upload_parameters.merge(vpc_subnet_id: 'my_subnet').to_json
      )
      # rubocop:enable RSpec/MessageSpies
      Backend::Api::Cloud.upload(user: user, target: 'ec2', vpc_subnet_id: 'my_subnet')
    end
  end
end
