class EntraId::GroupReconciler
  # Thin wrapper maintained for backward compatibility
  def reconcile_group(entra_group)
    entra_group.reconcile!
  end
end
