# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Service, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { user.home_project }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:service) { package.services }
  let(:url) { "#{CONFIG['source_url']}/source/#{home_project.name}/#{package.name}" }

  context '#addKiwiImport' do
    before do
      login(user)
      service.addKiwiImport
    end

    it 'posts runservice' do
      expect(a_request(:post, "#{url}?cmd=runservice&user=#{user}")).to have_been_made.once
    end

    it 'posts mergeservice' do
      expect(a_request(:post, "#{url}?cmd=mergeservice&user=#{user}")).to have_been_made.once
    end

    it 'posts waitservice' do
      expect(a_request(:post, "#{url}?cmd=waitservice")).to have_been_made.once
    end

    it 'has a kiwi_import service' do
      expect(service.has_element?("/services/service[@name='kiwi_import']")).to be true
    end
  end
end
