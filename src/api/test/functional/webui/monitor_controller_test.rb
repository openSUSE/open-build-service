require_relative '../../test_helper'

class Webui::MonitorControllerTest < Webui::IntegrationTest
  uses_transaction :test_reload_monitor

  def test_monitor # src/api/spec/controllers/webui/monitor_controller_spec.rb
    visit monitor_path
    assert find(:id, "header-logo")

    visit monitor_old_path
    assert find(:id, "header-logo")
  end

  def teardown
    Timecop.return
  end

  def test_reload_monitor # src/api/spec/controllers/webui/monitor_controller_spec.rb
    skip "random failures here on travis"
    use_js

    # as soon as we have only one API process...
    # Timecop.travel(2010, 7, 12)

    StatusHistory.transaction do
      time = Time.now.to_i
      400.times do |i|
        StatusHistory.create(time: time - i * 1.day, key: 'squeue_med_x86_64', value: i)
        StatusHistory.create(time: time - i * 1.day, key: 'squeue_high_x86_64', value: 0)
        StatusHistory.create(time: time - i * 1.day, key: 'building_x86_64', value: Random.rand(10..42))
        StatusHistory.create(time: time - i * 1.day, key: 'waiting_x86_64', value: Random.rand(10..42) * 1000)
      end
    end

    visit monitor_path
    select 'x86_64', from: 'architecture_display'
    select '1 year', from: 'time_display'

    page.wont_have_selector '.plotspinner'

    # this is pure guessing - hopeing May is always visible throughout the year
    # we can't use timecop as long as we have 2 processes
    page.must_have_selector(:xpath, '//div[text()="May" or text()="Mar" or text()="Jun"]')
    tickLabels = all('.tickLabel').each.map(&:text)
    assert(tickLabels.include?('Mar') || tickLabels.include?('May') || tickLabels.include?('Jun'))
  end
end
