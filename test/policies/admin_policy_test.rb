require "test_helper"

class AdminPolicyTest < ActiveSupport::TestCase
  test "admin may access the admin area" do
    assert AdminPolicy.new(users(:admin), :admin).access?
  end

  test "staff may not access the admin area" do
    assert_not AdminPolicy.new(users(:staff), :admin).access?
  end

  test "visitors may not access the admin area" do
    assert_not AdminPolicy.new(nil, :admin).access?
  end
end