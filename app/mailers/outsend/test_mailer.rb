module Outsend
  # "Send a test email" on Settings > Outsend. It names the install by the address it was sent
  # from (host:, the request's), and who it comes from once Send as has had its say.
  class TestMailer < ::ApplicationMailer
    def check(to:, host: nil)
      @host = host.presence || ENV.fetch("APP_HOST", "localhost")
      @sender = Connection.effective_sender
      mail to: to, subject: "Runwell can send email"
    end
  end
end
