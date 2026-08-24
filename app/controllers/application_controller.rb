class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_store

  helper_method :current_store

  private

  def set_current_store
    Current.store = Store.resolve(request.host)
  end

  def current_store
    Current.store
  end

  def require_current_store!
    return if Current.store.present?

    render plain: "Store not found", status: :not_found
  end
end
