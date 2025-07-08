class EntraId::User
  def initialize(payload)
    @payload = payload
  end

  def oid
    @payload[:id]
  end

  def id
    oid
  end

  def login
    @payload[:userPrincipalName]
  end

  def preferred_username
    login
  end

  def email
    @payload[:mail] || @payload[:userPrincipalName]
  end

  def given_name
    nametag.first_name
  end

  def surname
    nametag.last_name
  end

  def replicate_locally!
    user = User.find_by_identity(self) || User.new
    
    user.assign_attributes(user_attributes)
    user.save
  end

  def to_user_params
    user_attributes
  end

  private

    def nametag
      @nametag ||= EntraId::Nametag.new(
        given_name: @payload[:givenName],
        surname: @payload[:surname],
        display_name: @payload[:displayName]
      )
    end

    def user_attributes
      {
        login: email,
        firstname: given_name,
        lastname: surname,
        mail: email,
        oid: oid,
        synced_at: Time.current,
        auth_source_id: nil
      }
    end
end
