class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "hello@example.test")
  layout "mailer"
end
