class EntraId::Nametag
  def initialize(given_name:, surname:, display_name:)
    @given_name = given_name
    @surname = surname
    @display_name = display_name
  end

  def first_name
    @given_name.presence || parsed_display_name.first
  end

  def last_name
    @surname.presence || parsed_display_name.last
  end

  private

  attr_reader :given_name, :surname, :display_name

  def parsed_display_name
    @parsed_display_name ||= begin
      return ["Unknown", "User"] unless display_name.present?
      
      first, *rest = display_name.strip.split(/\s+/)
      [first, rest.any? ? rest.join(" ") : "User"]
    end
  end
end