class EntraId::User
  class << self
    def find_by(**kwargs)
      filter = kwargs.map { |k, v| "#{k} eq '#{v}'" }.join(" and ")

      client = EntraId::Graph::Client.new
      users = client.get(
        "users",
        filter: filter,
        select: [ "id", "userPrincipalName", "mail", "givenName", "surname", "displayName" ],
        top: 1
      )

      users.first ? new(users.first.with_indifferent_access) : nil
    end

    def sync_all
      client = EntraId::Graph::Client.new
      errors = []

      users = client.get(
        "users",
        select: [ "id", "userPrincipalName", "mail", "givenName", "surname", "displayName" ],
        top: 999
      )

      puts "Found #{users.size} users"

      users.each do |user_attrs|
        begin
          user = EntraId::User.new(user_attrs.with_indifferent_access)
          user.replicate_locally!

          print "."
        rescue => e
          errors << "Failed to process #{user_attrs["mail"]} (#{user_attrs["id"]}): #{e.message}"
          print "E"
        end
      end

      if errors.present?
        puts "\nFailures"
        puts "========"
        errors.each { |error| puts error }
      end
    end
  end

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
    local_user = ::User.find_by_identity(self)

    if local_user
      # Do not update the login for existing users
      attributes = user_attributes.except(:login)
      # Avoid generating security notifications if the email address in Redmine
      # is Foo.Bar@baz.com while in Entra is foo.bar@baz.com.
      attributes[:mail] = local_user.mail if local_user.mail.casecmp?(email)

      local_user.update!(attributes)
    else
      ::User.create!(user_attributes)
    end

    true
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
        status: User::STATUS_ACTIVE,
        synced_at: Time.current
      }
    end
end
