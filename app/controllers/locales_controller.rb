# Persisting a language choice changes state, so it is a POST.
#
# It used to be a GET link, and Turbo prefetching that link on hover was enough to
# rewrite the cookie: a pointer drifting across the switch silently changed the
# customer's language on the next page. A safe method must never have a side
# effect — this is exactly why.
class LocalesController < ApplicationController
  def update
    locale = params[:locale].to_s.to_sym.presence_in(I18n.available_locales)
    return redirect_back fallback_location: root_path if locale.blank?

    cookies[ApplicationController::LOCALE_COOKIE] = {
      value: locale.to_s,
      expires: ApplicationController::LOCALE_COOKIE_MAX_AGE.from_now,
      same_site: :lax
    }

    # Back to the same page, without a locale param left in the URL: the cookie is
    # the record of the choice now.
    redirect_back fallback_location: root_path, allow_other_host: false
  end
end
