require 'rails_helper'

RSpec.describe Webui::BuildresultHelper do
  include Webui::WebuiHelper
  let(:project) { create(:project) }
  let(:package) { create(:package, project: project) }
  let(:arch) { 'i586' }
  let(:repo) { create(:repository, project: project, architectures: [arch]) }

  describe '#arch_repo_table_cell' do
    let(:description) { Buildresult::STATUS_DESCRIPTION[key] }
    let(:status) { { 'code' => key, 'details' => description } }

    before do
      allow(helper).to receive(:valid_xml_id) do |rawid|
        rawid
      end
      allow(helper).to receive(:sprite_tag) do |icon, opts|
        sprite_tag(icon, opts)
      end

      assign(:statushash, statushash)
      assign(:project, project)
    end

    RSpec.shared_examples 'generic case' do
      context 'without status and statushash' do
        let(:statushash) { { repo.name => { arch => { package.name => { 'code' => key, 'details' => description } } } } }

        it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name)).to eq result }
      end

      context 'with status and without enable_help' do
        let(:hash_key) { key == 'scheduled' ? 'unknown' : 'scheduled' } # to have different key in the statushash
        let(:statushash) { { repo.name => { arch => { package.name => { 'code' => hash_key, 'details' => description } } } } }

        it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name, status, false)).to eq result2 }
      end
    end

    ['succeeded', 'failed', 'broken', 'dispatching', 'building', 'signing', 'finished', 'disabled', 'locked', 'unknown'].each do |key|
      context "with #{key}" do
        let(:key) { key }
        let(:encoded_description) { description.gsub("'", '&#39;') } # ' is encoded as &#39;
        let(:result) do
          "<td class=\"status_#{key} buildstatus nowrap\"><a title=\"#{encoded_description}\" rel=\"nofollow\" " \
            "href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\">#{key}</a> <img title=\"#{encoded_description}\" class=" \
            "\"icons-help\" alt=\"#{encoded_description}\" src=\"/images/s.gif\" /></td>"
        end
        let(:result2) do
          "<td class=\"status_#{key} buildstatus nowrap\"><a title=\"#{encoded_description}\" rel=\"nofollow\" " \
            "href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\">#{key}</a></td>"
        end

        include_examples 'generic case'
      end
    end

    ['unresolvable', 'blocked', 'excluded'].each do |key|
      context "with #{key}" do
        let(:key) { key }
        let(:result) do
          "<td class=\"status_#{key} buildstatus nowrap\"><a title=\"#{description}\" id=\"id-#{package}_#{repo}_#{arch}\" class=\"#{key}\" " \
            "href=\"#\">#{key}</a> <img title=\"#{description}\" class=\"icons-help\" alt=\"#{description}\" src=\"/images/s.gif\" /></td>"
        end
        let(:result2) do
          "<td class=\"status_#{key} buildstatus nowrap\"><a title=\"#{description}\" id=\"id-#{package}_#{repo}_#{arch}\" class=\"#{key}\" " \
            "href=\"#\">#{key}</a></td>"
        end

        include_examples 'generic case'
      end
    end

    context 'with scheduled' do
      let(:key) { 'scheduled' }
      let(:result) do
        "<td class=\"status_scheduled_warning buildstatus nowrap\"><a title=\"#{description}\" id=\"id-#{package}_#{repo}_#{arch}\" class=" \
          '"scheduled" href="#">scheduled</a>' \
          " <img title=\"#{description}\" class=\"icons-help\" alt=\"#{description}\" src=\"/images/s.gif\" />" \
          '</td>'
      end
      let(:result2) do
        "<td class=\"status_scheduled_warning buildstatus nowrap\"><a title=\"#{description}\" id=\"id-#{package}_#{repo}_#{arch}\" class=" \
          '"scheduled" href="#">scheduled</a></td>'
      end

      include_examples 'generic case'
    end

    context 'without status' do
      let(:statushash) { { repo.name => { arch => { package.name => nil } } } }
      let(:result) do
        "<td class=\"  buildstatus nowrap\"><a rel=\"nofollow\" href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\"></a></td>"
      end

      it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name)).to eq result }
    end
  end
end
