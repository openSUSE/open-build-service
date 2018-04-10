# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Webui::MonitorController, vcr: true do
  describe 'GET #index' do
    before do
      get :index
    end

    it { is_expected.to render_template('webui/monitor/index') }
  end

  describe 'GET #old' do
    before do
      get :old
    end

    it { is_expected.to render_template('webui/monitor/old') }
  end

  describe 'GET #update_building' do
    before do
      get :update_building, xhr: true
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response).to have_key('simulated') } # it relays on a simulated VCR cassette
  end

  describe 'GET #events' do
    before do
      # x86_64
      create_list(:status_history, 10, source: 'squeue_high')
      create_list(:status_history, 20, source: 'squeue_med', range: 0..400)
      create_list(:status_history, 30, source: 'building', range: 10..42)
      create_list(:status_history, 10, source: 'waiting', range: 10_000..42_000)
      # i586
      create_list(:status_history, 5, source: 'squeue_high', architecture: 'i586')
      get :events, params: { arch: 'x86_64', range: 8761 }, xhr: true
      @json_response = JSON.parse(response.body)
    end

    it { expect(@json_response['events_max']).to be <= 800 }
    it { expect(@json_response['jobs_max']).to be <= 84_000 }
    it { expect(@json_response['squeue_high'].length).to eq(10) }
    it { expect(@json_response['squeue_med'].length).to eq(20) }
    it { expect(@json_response['building'].length).to eq(30) }
    it { expect(@json_response['waiting'].length).to eq(10) }
  end
end
