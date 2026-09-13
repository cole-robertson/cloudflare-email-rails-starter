class ApplicationMailbox < ActionMailbox::Base
  routing all: :main
  # routing /something/i => :somewhere
end
