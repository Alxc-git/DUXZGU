module LegalHelper
  # A placeholder the shop owner still has to replace. Loud on purpose: shipping a
  # policy with one of these left in it is worse than having no policy.
  def legal_todo(key)
    tag.mark(t("legal.#{key}"), class: "legal__todo", title: t("legal.todo_note"))
  end

  # Policy paragraphs carry inline markup and interpolations, so they are
  # translated as _html keys and rendered through this one helper rather than
  # sprinkling `.html_safe` across the views.
  def legal_p(key, **args)
    tag.p(t("legal.#{key}", **args).html_safe)
  end
end
