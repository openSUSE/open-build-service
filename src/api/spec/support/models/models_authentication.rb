module ModelsAuthentication
  def login(user)
    User.current = user
  end

  def logout
    User.current = nil
  end
end

RSpec.configure do |c|
  c.include ModelsAuthentication, type: :model
  c.include ModelsAuthentication, type: :mailer
end
