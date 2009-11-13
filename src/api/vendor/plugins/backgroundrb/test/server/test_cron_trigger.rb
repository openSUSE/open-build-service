require File.join(File.dirname(__FILE__) + "/..","bdrb_test_helper")

context "Cront Trigger in general" do
  specify "should let tasks running at given time interval run" do
    # every 5 seconds
    a = BackgrounDRb::CronTrigger.new("*/5 * * * * * *")
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    firetime = a.fire_after_time(t_time)
    firetime.min.should == 53
    firetime.sec.should == 45
    firetime.hour.should == 20

    # 5 minute of every hour
    a = BackgrounDRb::CronTrigger.new("0 5 * * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.sec.should == 0
    firetime.min.should == 5
    firetime.hour.should == 21
    firetime.day.should == 13

    # every 5 minute
    a = BackgrounDRb::CronTrigger.new("0 */5 * * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.sec.should == 0
    firetime.min.should == 55
    firetime.hour.should == 20
    firetime.day.should == 13

    # every 5 AM of every day
    a = BackgrounDRb::CronTrigger.new("0 0 5 * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 5
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 14
    firetime.month.should == 2

    a = BackgrounDRb::CronTrigger.new("*/10 * * * * * ")
    t_time = Time.parse("Wed Feb 13 23:17:55 +0530 2008")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 23
    firetime.min.should == 18
    firetime.sec.should == 0
    firetime.day.should == 13
    firetime.month.should == 2
  end

  specify "should return correct firetime for hour intervals" do
    # every 5 hour
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 14
    firetime.month.should == 2
  end

  specify "should return firetime based on wday restriction" do
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    # on sunday and monday it should run every 5 th hour
    a = BackgrounDRb::CronTrigger.new("0 0 */5 * * 0-1 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 17
    firetime.month.should == 2

    t_time2 = Time.parse("Sun Feb 17 20:53:43 +0530 2008")
    firetime = a.fire_after_time(t_time2)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 18
    firetime.month.should == 2

  end

  specify "should wrap to next week for wday restirctions" do
    a = BackgrounDRb::CronTrigger.new("0 0 */5 * * 0-1 *")
    t_time = Time.parse("Mon Feb 18 20:53:43 +0530 2008")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 24
    firetime.month.should == 2
  end

  specify "should return firetime based on day restriction" do
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    # 21st of every month run every 5 hour
    a = BackgrounDRb::CronTrigger.new("0 0 */5 21 * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 21
    firetime.month.should == 2

    t_time = Time.parse("Wed Feb 22 20:53:43 +0530 2008")
    # 21st of every month run every 5 hour
    a = BackgrounDRb::CronTrigger.new("0 0 */5 21 * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 21
    firetime.month.should == 3
  end

  specify "for feb month should take into account day count" do
    t_time = Time.parse("Thu Feb 28 20:53:43 +0530 2008")
    # 21st of every month run every 5 hour
    a = BackgrounDRb::CronTrigger.new("0 0 */5 30 * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 30
    firetime.month.should == 3
  end

  specify "should take care if number of days is not available in month" do
    t_time = Time.parse("Tue Nov 12 20:53:43 +0530 2007")
    # 21st of every month run every 5 hour
    a = BackgrounDRb::CronTrigger.new("0 0 */5 31 * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 31
    firetime.month.should == 12
  end

  specify "should take care of periodic variations in day restrictions" do
    t_time = Time.parse("Tue Aug 12 20:53:43 +0530 2007")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 */2 1-5 * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 1
    firetime.month.should == 1
    firetime.year.should == 2008

    t_time = Time.parse("Tue Aug 12 20:53:43 +0530 2007")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 */3 1-5 * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 1
    firetime.month.should == 1
    firetime.year.should == 2008

    t_time = Time.parse("Tue Aug 12 20:53:43 +0530 2007")
    a = BackgrounDRb::CronTrigger.new("0 0 */1 */7 1-5 * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 1
    firetime.month.should == 1
    firetime.year.should == 2008
  end

  specify "should return firetime based on hour restriction" do
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 14
    firetime.month.should == 2
  end

  specify "should take care of both fuck restrictions" do

    # in case of conflict between day and wday options, we should chose one closer to current time
    t_time = Time.parse("Tue Aug 12 20:53:43 +0530 2007")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 */3 1-5 3-5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 1
    firetime.wday.should == 2
    firetime.month.should == 1
    firetime.year.should == 2008
  end

  specify "for user reported trigger" do
    # on friday
    t_time = Time.parse("Fri Jan 18 4:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0/5 09-17 * * 1,3,5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 9
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 5
    firetime.month.should == 1
    firetime.year.should == 2008

    t_time = Time.parse("Fri Jan 18 9:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0/5 09-17 * * 1,3,5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 9
    firetime.min.should == 55
    firetime.sec.should == 0
    firetime.wday.should == 5
    firetime.month.should == 1
    firetime.day.should == 18
    firetime.year.should == 2008

    t_time = Time.parse("Sat Jan 19 4:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0/5 09-17 * * 1,3,5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 9
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 1
    firetime.month.should == 1
    firetime.day.should == 21
    firetime.year.should == 2008

    t_time = Time.parse("Mon Jan 21 4:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0/5 09-17 * * 1,3,5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 9
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 1
    firetime.month.should == 1
    firetime.day.should == 21
    firetime.year.should == 2008

    t_time = Time.parse("Tue Jan 1 4:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0/5 09-17 * * 1,3,5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 9
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 3
    firetime.month.should == 1
    firetime.day.should == 2
    firetime.year.should == 2008
  end

  specify "should return firetime based on month restriction" do
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0 */5 * * * *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 0
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.day.should == 14
    firetime.month.should == 2
  end

  specify "should run for weekdays " do
    t_time = Time.parse("Wed Feb 13 20:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0 2 * * 1-5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 2
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 4

    t_time = Time.parse("Fri June 6 20:53:43 +0530 2008")
    a = BackgrounDRb::CronTrigger.new("0 0 2 * * 1-5 *")
    firetime = a.fire_after_time(t_time)
    firetime.hour.should == 2
    firetime.min.should == 0
    firetime.sec.should == 0
    firetime.wday.should == 1
  end
end
