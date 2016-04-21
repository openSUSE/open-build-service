require "spec_helper"
#for getting spec file

RSpec.describe "Checking Build Results" do

  it "should be able to Overview Build Results" do
    visit("/project/show/home:Admin")
    click_link('Overview')
    expect(page).to have_content("Build Results")
  end

  it "should be able to check Build Results and see succeeded package built" do
    sleep(10)
    while page.has_content?("State needs recalculation") do
      sleep(3)
      page.evaluate_script("window.location.reload()")
    end
    all_unresolvable = 0 
    visit "/project/show/home:Admin/"
    counter = 100
    while counter > 0 do
      page.evaluate_script("window.location.reload()")
      puts "Refreshed Build Results @ #{Time.now}, #{counter} retries left."
      succeed_links=page.all('a', :text =>'succeeded: 1')
      unresolvable_links=page.all('a', :text =>'unresolvable: 1')
      if ( unresolvable_links.length == 2 ) then
        counter = 0
        all_unresolvable = 1
      end
      if ( succeed_links.length == 2 ) then
        counter = 0
      else
        counter -= 1
        sleep(3)
      end
    end
    page.all('a', :text =>'succeeded: 1', :count => 2)

    if ! all_unresolvable then
      visit "/package/live_build_log/home:Admin/obs-build/openSUSE_Tumbleweed/i586"
      begin
        Timeout.timeout(160) {
          if page.has_content?("No live log available:") then
            page.evaluate_script("window.location.reload()")
            first(:link, "Start refresh").click
          end
          expect(page).to have_selector("div#log_space_wrapper", :wait => 20)
          expect(page).to have_content('finished "build build.spec"', :wait => 160)
        }
      rescue Timeout::Error
        page.evaluate_script("window.location.reload()")
        expect(page).to have_content('finished "build build.spec"', :wait => 120)
      end
      visit "/package/live_build_log/home:Admin/obs-build/openSUSE_Leap_42.1/x86_64"
      begin
        Timeout.timeout(90) {
          expect(page).to have_selector("div#log_space_wrapper", :wait => 20)
          page.evaluate_script("window.location.reload()") if page.has_content?("No live log available:")
          next if page.has_content?("Build finished")
          expect(page).to have_content('finished "build build.spec"', :wait => 90)
        }
      rescue Timeout::Error
        page.evaluate_script("window.location.reload()")
        next if page.has_content?("Build finished")
        expect(page).to have_content('finished "build build.spec"', :wait => 60)
      end
    end
  end

end
