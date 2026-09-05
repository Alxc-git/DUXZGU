module FlavorExperienceHelper
  def storefront_flavor_options
    Flavor::ALL.to_h do |flavor|
      [ flavor.slug, { name: flavor.name, note: flavor.note, color: flavor.color_var,
        spot: flavor.spot_var, src: asset_path(flavor.card_image),
        srcset: storefront_image_srcset(flavor.card_image),
        hero: { src: asset_path(flavor.scene_image), srcset: storefront_image_srcset(flavor.scene_image), focus: flavor.scene_focus,
          mobileSrc: asset_path(flavor.mobile_scene_image), mobileSrcset: storefront_image_srcset(flavor.mobile_scene_image) } } ]
    end
  end

  def flavor_choice_data(flavor)
    { flavor_choice: flavor.slug, action: "click->flavor#choose pointerenter->flavor#preload focus->flavor#preload" }
  end
end
