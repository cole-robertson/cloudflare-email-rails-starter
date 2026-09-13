require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "sign-in redirects render HTML even when Turbo offers stream format" do
    sign_in_as users(:one)
    get "/", headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "a[href='/mailboxes/']", text: "Open your mailboxes"
  end
end
