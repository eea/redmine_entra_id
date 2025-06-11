class EntraId::User
  attr_reader :oid, :email, :given_name, :surname

  def initialize(oid:, email:, given_name:, surname:)
    @oid = oid
    @email = email
    @given_name = given_name
    @surname = surname
  end

  def id
    oid
  end

  def preferred_username
    email
  end

  def replicate_locally!
    user = User.find_by_identity(self) || User.new
    
    user.assign_attributes(user_attributes)
    user.save
  end

  private

    def user_attributes
      {
        login: email,
        firstname: given_name,
        lastname: surname,
        mail: email,
        oid: oid,
        synced_at: Time.current
      }
    end
end
