require File.expand_path("../../../test_helper", __FILE__)

class EntraId::GroupTest < ActiveSupport::TestCase
  setup do
    @group_id = "entra-group-oid-1"
    @user_oid =  "entra-user-oid-1"
    @user = User.find(2) # jsmith
    @user.update_column(:oid, @user_oid)

    @project = Project.find(1) # eCookbook
    @other_project = Project.find(2) # OnlineStore
    @role = Role.find(1) # Manager
  end

  test "creates new group in Redmine" do
    group = EntraId::Group.new(oid: @group_id, display_name: "Engineering", members: [{ "id" => @user.oid }])

    group.sync

    redmine_group = Group.find_by(oid: @group_id)
    assert redmine_group, "Group should be created"
    assert_includes redmine_group.user_ids, @user.id
  end

  test "updates existing group in Redmine" do
    group = EntraId::Group.new(oid: @group_id, display_name: "Engineering", members: [{ "id" => @user.oid }])
    group.sync

    EntraId::Group.new(oid: @group_id,display_name: "Engineering Renamed",members: [{ "id" => @user.oid }]).sync

    redmine_group = Group.find_by(oid: @group_id)
    assert_equal "🆔 Engineering Renamed", redmine_group.name
  end

  test "removing a user from the group removes inherited roles from all projects" do
    group = EntraId::Group.new(oid: @group_id, display_name: "Staff", members: [{ "id" => @user.oid }])
    group.sync

    redmine_group = Group.find_by!(oid: @group_id)
    [@project, @other_project].each do |project|
      Member.create!(project: project, principal: redmine_group, role_ids: [@role.id])
    end

    assert inherited_role?(@user, @project)
    assert inherited_role?(@user, @other_project)

    EntraId::Group.new(oid: @group_id,display_name: "Staff",members: []).sync

    assert_not inherited_role?(@user, @project)
    assert_not inherited_role?(@user, @other_project)
  end

  test "sync removes group users without oid" do
    redmine_group = Group.create!(oid: @group_id, lastname: "🆔 Staff")
    user_without_oid = User.find(3)
    another_user_without_oid = User.find(4)

    user_without_oid.update_column(:oid, nil)
    another_user_without_oid.update_column(:oid, nil)

    redmine_group.users << @user
    redmine_group.users << user_without_oid
    redmine_group.users << another_user_without_oid

    assert_includes redmine_group.user_ids, @user.id
    assert_includes redmine_group.user_ids, user_without_oid.id
    assert_includes redmine_group.user_ids, another_user_without_oid.id

    EntraId::Group.new(oid: @group_id, display_name: "Staff", members: [{ "id" => @user.oid }]).sync
    redmine_group.reload

    assert_includes redmine_group.user_ids, @user.id
    assert_not_includes redmine_group.user_ids, user_without_oid.id
    assert_not_includes redmine_group.user_ids, another_user_without_oid.id
  end

  private

    def inherited_role?(user, project)
      MemberRole.joins(:member)
        .where(members: { user_id: user.id, project_id: project.id })
        .where.not(inherited_from: nil)
        .exists?
    end
end
