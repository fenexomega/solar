module ControllerMacros
  def login_user(fix_user)
    fixtures :users

    before(:each) do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      user = users(fix_user)
      sign_in user
    end
  end
end