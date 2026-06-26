RSpec.describe Badge do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:request) do
    stub_request(:get, "#{CONFIG['source_url']}/build/#{user.home_project}/_result?locallink=1&multibuild=1&lastbuild=1" \
                       "&package=#{source_package}&view=status").and_return(body: body)
  end
  let(:results) { request && source_package.buildresult(source_project, show_all: false, lastbuild: true).results[source_package.name] }
  let(:badge) { Badge.new(type, results) }

  describe '#new' do
    RSpec.shared_examples 'tests for badge xml' do
      describe 'empty resultlist' do
        let(:body) { "<resultlist state=\"eb0459ee3b000176bb3944a67b7c44fa\">\n</resultlist>" }

        it 'displays the correct unknown state' do
          xml = Capybara.string(badge.xml)
          expect(xml).to have_text('unknown')
        end
      end

      describe 'failing resultlist' do
        let(:body) do
          %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
              <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="succeeded" state="building">
                <status package="my_package" code="succeeded" />
              </result>
              <result project="home:tom" repository="images" arch="x86_64" code="failed" state="building">
                <status package="my_package" code="failed" />
              </result>
            </resultlist>)
        end

        it 'displays the correct failed state' do
          xml = Capybara.string(badge.xml)
          expect(xml).to have_text(expected_failure)
        end
      end

      describe 'succeeded resultlist' do
        let(:body) do
          %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
            <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="succeeded" state="building">
              <status package="my_package" code="succeeded" />
            </result>
            <result project="home:tom" repository="images" arch="x86_64" code="succeeded" state="building">
              <status package="my_package" code="succeeded" />
            </result>
          </resultlist>)
        end

        it 'displays the correct succeeded state' do
          xml = Capybara.string(badge.xml)
          expect(xml).to have_text(expected_success)
        end
      end

      describe 'finished resultlist' do
        let(:body) do
          %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
              <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="finished" state="building">
                <status package="my_package" code="finished" />
              </result>
            </resultlist>)
        end

        it 'displays the correct unknown state' do
          xml = Capybara.string(badge.xml)
          expect(xml).to have_text('unknown')
        end
      end

      describe 'succeeded with disabled resultlist' do
        let(:body) do
          %(<resultlist state="eb0459ee3b000176bb3944a67b7c44fa">
              <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="succeeded" state="building">
                <status package="my_package" code="succeeded" />
              </result>
              <result project="home:tom" repository="images" arch="x86_64" code="succeeded" state="building">
                <status package="my_package" code="succeeded" />
              </result>
              <result project="home:tom" repository="openSUSE_Leap_42.1" arch="x86_64" code="disabled" state="building">
                <status package="my_package" code="disabled" />
              </result>
            </resultlist>)
        end

        it 'filters out the disabled' do
          xml = Capybara.string(badge.xml)
          expect(xml).to have_text(expected_success)
        end
      end
    end

    context 'without type specified' do
      let(:expected_success) { 'succeeded' }
      let(:expected_failure) { 'failed' }
      let(:type) { '' }

      it_behaves_like 'tests for badge xml'
    end

    context 'with percent type specified' do
      let(:expected_success) { '100%' }
      let(:expected_failure) { '50%' }
      let(:type) { 'percent' }

      it_behaves_like 'tests for badge xml'
    end
  end
end
