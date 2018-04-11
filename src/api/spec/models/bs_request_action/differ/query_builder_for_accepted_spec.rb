# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BsRequestAction::Differ::QueryBuilderForAccepted do
  describe '#build' do
    context 'with xsrcmd5 and oxsrcmd5' do
      let(:accept_info) do
        create(:bs_request_action_accept_info_with_action,
               opackage: 'opackage',
               oproject: 'oproject',
               xsrcmd5: 'xsrcmd5',
               oxsrcmd5: 'oxsrcmd5')
      end
      let(:query) { BsRequestAction::Differ::QueryBuilderForAccepted.new(bs_request_action_accept_info: accept_info).build }
      it { expect(query[:opackage]).to eq('opackage') }
      it { expect(query[:oproject]).to eq('oproject') }
      it { expect(query[:rev]).to eq('xsrcmd5') }
      it { expect(query[:orev]).to eq('oxsrcmd5') }
    end

    context 'without xsrcmd5 and oxsrcmd5 but with srcmd5 and osrcmd5' do
      let(:accept_info) do
        create(:bs_request_action_accept_info,
               srcmd5: 'srcmd5',
               osrcmd5: 'osrcmd5')
      end
      let(:query) { BsRequestAction::Differ::QueryBuilderForAccepted.new(bs_request_action_accept_info: accept_info).build }
      it { expect(query[:rev]).to eq('srcmd5') }
      it { expect(query[:orev]).to eq('osrcmd5') }
    end

    context 'without osrcmd5 and oxsrcmd5' do
      let(:accept_info) { create(:bs_request_action_accept_info) }
      let(:query) { BsRequestAction::Differ::QueryBuilderForAccepted.new(bs_request_action_accept_info: accept_info).build }
      it { expect(query[:orev]).to eq('0') }
    end
  end
end
