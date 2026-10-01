module Outsend
  # The install's Outsend account: its API key (one row), and a note of the last message sent
  # and the last failure. The key may also come from the encrypted credentials
  # (outsend: api_key:, as Runwell v1 keeps it) or OUTSEND_API_KEY in the environment, for
  # installs that keep secrets there; a key saved here wins, then credentials, then the environment.
  class Connection < ::ApplicationRecord
    self.table_name = "outsend_connections"

    # Outsend's SMTP daemon: plain auth, the API key as the password, after STARTTLS (it refuses
    # auth without it).
    SMTP = { address: "smtp.getoutsend.com", port: 2587, user_name: "outsend", authentication: :plain,
             enable_starttls_auto: true, open_timeout: 5, read_timeout: 10 }.freeze

    encrypts :api_key

    normalizes :send_as_email, with: ->(value) { value.strip.downcase.presence }
    normalizes :send_as_name, with: ->(value) { value.strip.presence }

    validates :send_as_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "isn't an email address" }, allow_nil: true
    validate :send_as_on_a_real_domain
    validate :ensure_singleton, on: :create

    class << self
      def current = first
      def for_settings = first || new
      def record = first || create!

      # The key in use, if any.
      def key = current&.api_key.presence || credentials_key || ENV["OUTSEND_API_KEY"].presence

      # Where the key in use comes from: "settings", "credentials", "environment" or nil.
      def key_source
        if current&.api_key.present? then "settings"
        elsif credentials_key then "credentials"
        elsif ENV["OUTSEND_API_KEY"].present? then "environment"
        end
      end

      def credentials_key = Rails.application.credentials.dig(:outsend, :api_key).presence

      def smtp_settings(key) = SMTP.merge(password: key)

      def note_delivery!
        record.then { it.update_columns(last_delivered_at: Time.current, delivered_count: it.delivered_count + 1, last_error: nil, last_error_at: nil) }
      end

      def note_error!(message)
        record.update_columns(last_error: message.to_s.truncate(500), last_error_at: Time.current)
      end
    end

    def configured? = self.class.key.present?

    # The address mail through Outsend comes from: the one set here, else the install's sender.
    def self.from_address(original = nil)
      send_as = current&.send_as_email.presence or return
      name = current.send_as_name.presence || Mail::Address.new(original.to_s).display_name.presence rescue nil
      Mail::Address.new(send_as).tap { it.display_name = name if name }.to_s
    end

    # A domain Outsend will refuse whatever the account holds: no dot, or this machine.
    def self.unsendable_domain?(address)
      domain = Mail::Address.new(address.to_s).domain.to_s rescue ""
      domain.blank? || !domain.include?(".") || domain.in?(%w[localhost localhost.localdomain]) || domain.end_with?(".local", ".test", ".example")
    end

    # Who mail through Outsend will come from right now.
    def self.effective_sender = from_address(Setting.current.mail_sender) || Setting.current.mail_sender

    def forget_key! = update!(api_key: nil)

    private
      def send_as_on_a_real_domain
        errors.add(:send_as_email, "needs a domain verified in Outsend, not this machine's") if send_as_email && self.class.unsendable_domain?(send_as_email)
      end

      def ensure_singleton
        errors.add(:base, "There is already an Outsend connection") if Connection.exists?
      end
  end
end
