module User::Identifiable
  extend ActiveSupport::Concern

  included do
    scope :by_login, ->(login) { where("LOWER(login) = LOWER(?)", login) }
    scope :by_email, ->(address) { joins(:email_addresses).merge(EmailAddress.by_address(address)) }

    scope :by_email_or_login, ->(identifier) { by_email(identifier).or(User.by_login(identifier)) }

    scope :not_admin, -> { where(admin: false) }
    scope :identified, -> { where.not(oid: nil) }
    scope :stale_since, ->(time) { where("synced_at IS NULL OR synced_at < ?", time) }
  end

  class_methods do
    def find_by_identity(identity)
      user = find_by(oid: identity.id)
      user.present? ? user : by_email_or_login(identity.preferred_username).first
    end

    def create_from_entra_user(entra_user, sync_time)
      user = create!(entra_user.to_user_params.merge(
        status: User::STATUS_ACTIVE,
        synced_at: sync_time,
        auth_source_id: 1
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
      synced_at: sync_time,
      auth_source_id: 1
    ))
    Rails.logger.info "Updated user: #{login} (#{entra_user.oid})"
  rescue => e
    Rails.logger.error "Failed to update user #{entra_user.email}: #{e.message}"
    raise
  end

  def entra_id_authenticated?
    oid.present?
  end
end
