module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin_user!

    helper_method :current_admin_user

    private

    def current_admin_user
      @current_admin_user ||= AdminUser.find_by(id: session[:admin_user_id])
    end

    def require_admin_user!
      return if current_admin_user.present?

      redirect_to admin_login_path, alert: "Please sign in"
    end
  end
end
