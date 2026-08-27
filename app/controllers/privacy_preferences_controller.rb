class PrivacyPreferencesController < ApplicationController
  def update
    choice = params[:analytics].to_s.presence_in(PrivacyConsent::CHOICES) || PrivacyConsent::DECLINED

    cookies.encrypted[PrivacyConsent::COOKIE_NAME] = {
      value: choice,
      expires: 1.year.from_now,
      same_site: :lax,
      secure: Rails.env.production?,
      httponly: true
    }

    redirect_back fallback_location: root_path, status: :see_other
  end
end
