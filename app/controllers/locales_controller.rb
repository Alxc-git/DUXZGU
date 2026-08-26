require "uri"

# Changing the language is a preference change, so it goes through a POST.
#
# As a GET it was being triggered by Turbo's link prefetching: hovering anywhere
# near the switch quietly fetched the other language and wrote its cookie, which
# reset the choice on the next page.
class LocalesController < ApplicationController
  skip_after_action :track_visit

  def update
    chosen = params[:locale].to_s.to_sym.presence_in(I18n.available_locales)
    remember_locale(chosen) if chosen

    redirect_to return_path, allow_other_host: false
  end

  private

  # The `locale` query parameter outranks the cookie, so returning to a URL that
  # still carries one would undo the choice that was just made — and leave the
  # switch stuck on that language for good. It is stripped here.
  def return_path
    referer = request.referer.presence or return root_path

    uri = URI.parse(referer)
    return root_path unless uri.host.nil? || uri.host == request.host

    query = Rack::Utils.parse_nested_query(uri.query).except("locale")
    uri.query = query.any? ? query.to_query : nil

    [ uri.path.presence || "/", uri.query.present? ? "?#{uri.query}" : nil ].compact.join
  rescue URI::InvalidURIError
    root_path
  end
end
