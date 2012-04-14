require 'spec_helper'

describe Micropost do

  before(:each) do
    @user = Factory(:user)
    @attr = { :content => "value for content" }
  end

  it "should create a new instance given valid attributes" do
    @user.microposts.create!(@attr)
  end

  describe "user associations" do

    before(:each) do
      @micropost = @user.microposts.create(@attr)
    end

    it "should have a user attribute" do
      @micropost.should respond_to(:user)
    end

    it "should have the right associated user" do
      @micropost.user_id.should == @user.id
      @micropost.user.should == @user
    end
  end

  describe "validations" do

    it "should require a user id" do
      Micropost.new(@attr).should_not be_valid
    end

    it "should require nonblank content" do
      @user.microposts.build(:content => "  ").should_not be_valid
    end

    it "should reject long content" do
      @user.microposts.build(:content => "a" * 141).should_not be_valid
    end
  end

  describe "#direct_message_format?" do
    context "when content starts with 'd'" do
      it "should return true if username is valid" do
        Factory(:user, :username => "recipient", :email => 'r@xmpl.com')
        micropost = @user.microposts.build(:content => "d recipient valid direct message")
        micropost.direct_message_format?.should be_true
      end

      it "should return false if username is invalid" do
        micropost = @user.microposts.build(:content => "d invalid_recipient invalid direct message")
        micropost.direct_message_format?.should be_false
      end
    end
  end

  describe "#to_direct_message_hash" do
    it "should return a hash that can be readily sent to DirectMessage#new" do
      Factory(:user, :username => "recipient", :email => 'r@xmpl.com')
      micropost = @user.microposts.build(:content => "d recipient valid direct message")
      direct_message = DirectMessage.new( micropost.to_direct_message_hash )
      direct_message.should be_valid
    end
  end

  describe "from_users_followed_by" do

    before(:each) do
      @other_user = Factory(:user, :email => Factory.next(:email),
                                   :username => Factory.next(:username))
      @third_user = Factory(:user, :email => Factory.next(:email),
                                   :username => Factory.next(:username))

      @user_post  = @user.microposts.create!(:content => "foo")
      @other_post = @other_user.microposts.create!(:content => "bar")
      @third_post = @third_user.microposts.create!(:content => "baz")

      @user.follow!(@other_user)
    end

    it "should have a from_users_followed_by class method" do
      Micropost.should respond_to(:from_users_followed_by)
    end

    it "should include the followed user's microposts" do
      Micropost.from_users_followed_by(@user).should include(@other_post)
    end

    it "should include the user's own microposts" do
      Micropost.from_users_followed_by(@user).should include(@user_post)
    end

    it "should not include an unfollowed user's microposts" do
      Micropost.from_users_followed_by(@user).should_not include(@third_post)
    end

    it "should include replies to the user in question" do
      third_reply = @third_user.microposts.create!(
        :content => "@#{@user.username} reply")
      Micropost.from_users_followed_by(@user).should include( third_reply )
    end
  end

  describe "replies (i.e. micropost body contains @username)" do
    before(:each) do
      @recipient1 = Factory(:user, :username => 'r1', :email => 'ex@mple1.com')
      @recipient2 = Factory(:user, :username => 'r2', :email => 'ex@mple2.com')
      @recipient3 = Factory(:user, :username => 'r3', :email => 'ex@mple3.com')
      @micropost = @user.microposts.create!(:content => "@r1, @r2 talk to @r3")
    end

    it "should be associated with users whom that username belongs to" do
      @micropost.replied_users.should == [@recipient1, @recipient2, @recipient3]
    end

    context "when this micropost is deleted" do
      it "should delete associated replied-to users" do
        @micropost.destroy
        associations = Recipient.where("micropost_id = #{@micropost.id}")
        associations.should be_blank
      end
    end
  end
end
