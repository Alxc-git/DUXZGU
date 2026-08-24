module Admin
  class SessionsController < ApplicationController
    layout "admin"

    def new; end

    def create
      admin_user = AdminUser.find_by(email: params[:email].to_s.downcase)

      if admin_user&.authenticate(params[:password])
        reset_session
        session[:admin_user_id] = admin_user.id
        redirect_to admin_root_path
      else
        redirect_to admin_login_path, alert: "Invalid email or password"
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Signed out"
    end
  end
end
