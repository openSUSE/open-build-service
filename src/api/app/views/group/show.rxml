xml.group do
  xml.title @group.title

  xml.person do
    @involved_users.each do |gu|
        xml.person :userid => gu.user.login
    end
  end

end
