module ModelsAuthentification
  def login(user)
    User.current = user
  end

  def logout
    User.current = nil
  end
end

RSpec.configure do |c|
  c.include ModelsAuthentification, type: :model
  c.include ModelsAuthentification, type: :mailer
end
