module User::Identifiable
  extend ActiveSupport::Concern

  included do
    # EntraID-specific scopes
    scope :identified, -> { where.not(oid: nil) }
    scope :stale_since, ->(time) { where("synced_at IS NULL OR synced_at < ?", time) }
    

    alias_method :delete_unsafe_attributes_without_entra_id, :delete_unsafe_attributes
    alias_method :delete_unsafe_attributes, :delete_unsafe_attributes_with_entra_id
  end

  class_methods do
    def find_by_identity(identity)
      user = find_by(oid: identity.id)
      return user if user.present?
      
      # Try finding by email first, then by login
      find_by_mail(identity.preferred_username) || find_by_login(identity.preferred_username)
    end

    def create_from_entra_user(entra_user, sync_time)
      user = create!(entra_user.to_user_params.merge(
        status: User::STATUS_ACTIVE,
        synced_at: sync_time
      ))
      Rails.logger.info "Created user: #{user.login} (#{entra_user.oid})"
      user
    rescue => e
      Rails.logger.error "Failed to create user #{entra_user.email}: #{e.message}"
      raise
    end
  end

  def sync_with_identity(identity)
    update!(identity.to_user_params.except(:login, :mail))
  end

  def sync_from_entra_user(entra_user, sync_time)
    update!(entra_user.to_user_params.except(:login).merge(
      status: User::STATUS_ACTIVE,
      synced_at: sync_time
    ))
    Rails.logger.info "Updated user: #{login} (#{entra_user.oid})"
  rescue => e
    Rails.logger.error "Failed to update user #{entra_user.email}: #{e.message}"
    raise
  end

  def authenticated_via_entra?
    oid.present?
  end

  def delete_unsafe_attributes_with_entra_id(attrs, user = User.current)
    # Remove protected fields for Entra ID users
    if authenticated_via_entra?
      attrs = attrs.except('firstname', 'lastname', 'mail')
    end
    
    delete_unsafe_attributes_without_entra_id(attrs, user)
  end
end
