module Admin
  module NavigationHelper
    # A sidebar entry that knows when it is the page you are on. Matching on the
    # path prefix keeps nested pages (an order, a product form) marked under their
    # section rather than leaving the sidebar looking inert.
    def admin_nav_link(label, path, icon_name)
      classes = [ "admin-sidebar__link" ]
      classes << "admin-sidebar__link--active" if admin_nav_active?(path)

      link_to path, class: classes.join(" "), aria: { current: admin_nav_active?(path) ? "page" : nil } do
        safe_join([ icon(icon_name, size: 18), tag.span(label) ])
      end
    end

    ORDER_STATUS_LABELS = {
      "pending" => "En attente",
      "checkout_created" => "Paiement ouvert",
      "paid" => "Payee",
      "processing" => "En traitement",
      "submitted_to_supplier" => "Transmise",
      "shipped" => "Expediee",
      "delivered" => "Livree",
      "cancelled" => "Annulee",
      "refunded" => "Remboursee",
      "failed" => "Echec"
    }.freeze

    def order_status_label(status)
      ORDER_STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
    end

    # The app runs on the default :en locale, so dates are spelled out here rather
    # than through I18n.l, which would print "Aug".
    def admin_short_datetime(time)
      local = time.in_time_zone
      "#{local.day} #{StorefrontHelper::MONTHS_FR[local.month - 1]} #{local.strftime('%H:%M')}"
    end

    def admin_nav_active?(path)
      current = request.path
      return current == path if path == admin_root_path

      current == path || current.start_with?("#{path}/")
    end
  end
end
