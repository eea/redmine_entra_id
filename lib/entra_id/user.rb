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
      time = Time.current
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
      local_user.sync_from_entra_user(self, Time.current)
    else
      ::User.create_from_entra_user(self, Time.current)
    end

    true
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
        synced_at: Time.current
      }
    end
end
