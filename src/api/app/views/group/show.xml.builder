# frozen_string_literal: true
xml.group do
  xml.title(@group.title)
  xml.email(@group.email) if @group.email
  @group.group_maintainers.each do |gm|
    xml.maintainer(userid: gm.user.login)
  end
  xml.person do
    @group.groups_users.each do |gu|
      xml.person(userid: gu.user.login)
    end
  end
end
