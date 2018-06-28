RSpec.shared_context 'a summary response' do
  let(:arch) { 'i586' }
  let(:summary_backend_url) { "#{CONFIG['source_url']}/build/#{staging_a}/_result?view=summary&repository=standard&arch=#{arch}" }
  let(:status) { 'building' }
  let(:summary_backend_response) do
    %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
      <result project='openSUSE:Factory:Staging:A' repository='standard' arch="#{arch}" code="#{status}" state="#{status}">
        <summary>
          <statuscount code='failed' count='1'/>
          <statuscount code='unresolvable' count='1'/>
          <statuscount code='building' count='24'/>
        </summary>
      </result>
    </resultlist>)
  end
end
