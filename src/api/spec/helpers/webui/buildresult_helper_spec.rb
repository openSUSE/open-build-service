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

      assign(:statushash, statushash)
      assign(:project, project)
    end

    RSpec.shared_examples 'generic case' do
      context 'without status and statushash' do
        let(:statushash) { { repo.name => { arch => { package.name => { 'code' => key, 'details' => description } } } } }

        it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name)).to eq(result) }
      end

      context 'with status and without enable_help' do
        let(:hash_key) { key == 'scheduled' ? 'unknown' : 'scheduled' } # to have different key in the statushash
        let(:statushash) { { repo.name => { arch => { package.name => { 'code' => hash_key, 'details' => description } } } } }

        it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name, status, false)).to eq(result2) }
      end
    end

    ['succeeded', 'failed', 'broken', 'dispatching', 'building', 'signing', 'finished', 'disabled', 'locked', 'unknown'].each do |key|
      context "with #{key}" do
        let(:key) { key }
        let(:encoded_description) { description.gsub("'", '&#39;') } # ' is encoded as &#39;
        let(:result) do
          "<i class=\"fa fa-question-circle text-info mr-1\" data-content=\"#{encoded_description}\" data-placement=\"top\" "\
            'data-toggle="popover"></i>'\
            "<a data-content=\"#{encoded_description}\" data-placement=\"right\" data-toggle=\"popover\" rel=\"nofollow\" "\
            "class=\"build-state-#{key}\" href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\">#{key}</a>"
        end
        let(:result2) do
          "<a data-content=\"#{encoded_description}\" data-placement=\"right\" data-toggle=\"popover\" rel=\"nofollow\" "\
            "class=\"build-state-#{key}\" href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\">#{key}</a>"
        end

        include_examples 'generic case'
      end
    end

    ['unresolvable', 'blocked', 'excluded'].each do |key|
      context "with #{key}" do
        let(:key) { key }
        let(:result) do
          "<i class=\"fa fa-question-circle text-info mr-1\" data-content=\"#{description}\" data-placement=\"top\" data-toggle=\"popover\"></i>"\
            "<a id=\"id-#{package}_#{repo}_#{arch}\" class=\"build-state-#{key}\" data-content=\"#{description}\" data-placement=\"right\" "\
            "data-toggle=\"popover\" href=\"javascript:void(0);\">#{key}</a>"
        end
        let(:result2) do
          "<a id=\"id-#{package}_#{repo}_#{arch}\" class=\"build-state-#{key}\" data-content=\"#{description}\" data-placement=\"right\" "\
            "data-toggle=\"popover\" href=\"javascript:void(0);\">#{key}</a>"
        end

        include_examples 'generic case'
      end
    end

    context 'with scheduled' do
      let(:key) { 'scheduled' }
      let(:result) do
        "<i class=\"fa fa-question-circle text-info mr-1\" data-content=\"#{description}\" data-placement=\"top\" data-toggle=\"popover\"></i>"\
          "<a id=\"id-#{package}_#{repo}_#{arch}\" class=\"text-warning\" data-content=\"#{description}\" data-placement=\"right\" "\
          "data-toggle=\"popover\" href=\"javascript:void(0);\">#{key}</a>"
      end
      let(:result2) do
        "<a id=\"id-#{package}_#{repo}_#{arch}\" class=\"text-warning\" data-content=\"#{description}\" data-placement=\"right\" "\
        "data-toggle=\"popover\" href=\"javascript:void(0);\">#{key}</a>"
      end

      include_examples 'generic case'
    end

    context 'without status' do
      let(:statushash) { { repo.name => { arch => { package.name => nil } } } }
      let(:result) do
        '<a data-placement="right" data-toggle="popover" rel="nofollow" class=" " '\
         "href=\"/package/live_build_log/#{project}/#{package}/#{repo}/#{arch}\"></a>"
      end

      it { expect(helper.arch_repo_table_cell(repo.name, arch, package.name)).to eq(result) }
    end
  end
end
