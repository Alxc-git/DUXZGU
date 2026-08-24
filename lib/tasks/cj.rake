namespace :cj do
  desc "List CJ variants for the storefront product so they can be mapped to local colours"
  task variants: :environment do
    store = Store.find_by(domain: ENV.fetch("STORE_DOMAIN", "localhost"))
    abort "Store not found. Pass STORE_DOMAIN=your-domain if needed." if store.blank?

    product = store.products.find_by(slug: ENV.fetch("PRODUCT_SLUG", "montre-chronographe-sport"))
    abort "Product not found. Pass PRODUCT_SLUG=your-slug if needed." if product.blank?

    if product.supplier_sku.blank? && product.supplier_product_id.blank?
      abort "Product has no CJ supplier_sku or supplier_product_id."
    end

    client = Suppliers.for(store)
    params = product.supplier_product_id.present? ? { pid: product.supplier_product_id } : { productSku: product.supplier_sku }
    response = client.get("/product/variant/query", params)
    variants = Array(response["data"])

    puts "CJ product: #{product.name}"
    puts "SKU: #{product.supplier_sku.presence || '-'}"
    puts "Product ID: #{product.supplier_product_id.presence || '-'}"
    puts

    if variants.empty?
      puts "No variants returned by CJ."
      next
    end

    variants.each do |variant|
      puts [
        "vid=#{variant['vid']}",
        "sku=#{variant['variantSku']}",
        "name=#{variant['variantNameEn'].presence || variant['variantName']}",
        "key=#{variant['variantKey']}",
        "price=#{variant['variantSellPrice']}"
      ].join(" | ")
    end

    puts
    puts "Copy each vid into Admin > Products > Edit > matching colour > CJ vid."
  rescue Suppliers::Cj::Client::Error => e
    abort <<~MESSAGE
      CJ request failed: #{e.message}

      Check CJ_API_KEY in .env and that this product is available to your CJ account, then run:
        bin/rails cj:variants
    MESSAGE
  end
end
