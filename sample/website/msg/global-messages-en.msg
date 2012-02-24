# These are the global messages for OI2 -- referenced by the templates
# in $WEBSITE_DIR/template and also by any template in the system

# Globals -- standard labels for stuff you use all the time
global.not_available = n/a
global.button.modify = Modify
global.button.add = Add
global.button.remove = Remove
global.button.save = Save
global.button.go = Go!
global.button.search = Search
global.button.filter = Filter
global.button.reset = Reset
global.button.default = Submit
global.button.submit = Submit

global.security_scope = Scope
global.security_label = Level
global.security_level.none  = None
global.security_level.read  = Read
global.security_level.write = Write
global.security_level.clear = Clear
global.label.error = Error
global.label.view = View
global.label.edit = Edit
global.label.nbsp = &nbsp;
global.label.new = New
global.label.yes = Yes
global.label.no = No

global.exception.security = Security violation. Object requires '[_1]' but got '[_2]'

# Attached to global templates
base_main.label.home = Home
base_main.label.users = Users
base_main.label.groups = Groups
base_main.label.pages = Pages
base_main.label.news = News
base_main.label.whats_new = What's New
base_main.label.search = Search
base_main.label.powered_by = Powered by OpenInteract!
base_main.label.logo = OpenInteract logo
base_main.phrase.questions =  Questions? Check out \
    <a href="http://www.openinteract.org/">the website</a>
c_a_error.title = Error
c_a_error.summary = This action encountered one or more errors:
error_msg.title = Error
error_not_found.title = File not found
error_not_found.summary = The URL you entered does not correspond to a page currently on \
    this website. Please check the url and try again.
error_not_found.signed = Sincerely,<br>The Management
error_not_found.referer =  <a href="[_1]">Back</a> to the page that brought you here
error_inactive.page_title = Error: Cannot Display Inactive Item
error_inactive.title = [_1] Inactive
error_inactive.summary = This item is currently inactive, which generally means it has not yet \
    been approved by an administrator. Check back later.
error_security.page_title = Error: No Rights to Object
error_security.title = Security Violation
error_security.summary = You have insufficient rights to display the requested object.
error_forbidden.title = Task is Forbidden
error_forbidden.summary = You cannot accomplish the task you have requested due to \
    security restrictions. If you believe there is a mistake, please \
    contact <a href="mailto:[_1]">The Administrator</a>.
error_forbidden.signed = Sincerely,<br>The Management
error_no_default.title = Task Cannot be Completed
error_no_default.summary = The module you requested does not have a default task \
    defined. Therefore your task cannot be completed. An email has already \
    been sent to the module author, but if you'd like you can \
    <a href="mailto:[_1]">do so yourself</a>.
error_no_default.signed = Sincerely,<br>The Management
form.default.user_list_first = User List...
global_javascript.confirm_remove = 'Do you want to remove ' + object_type + '(' + name + ') ?';
inactive_object.title = INACTIVE OBJECT
object_updates.new = brand new!
page_count.page_label = Page

# Common Actions

action.error.no_object_type = Object type is undefined. How can we know what to search \
    or return? Please set it in your action configuration using the key 'c_object_type'.
action.error.no_class_for_type = Class for given object type '[_1]' is undefined. This may \
    be a typo in your action configuration (check the key 'c_object_type').
action.error.no_id_field = Object ID field is undefined. We cannot know how to fetch an \
    existing object without it. Please define the key 'id_field' in your object configuration.
action.error.no_id_value = No value found in action parameters or request for ID field '[_1]'
action.error.no_alt_id_value = also checked alternative ID field '[_1]'.
action.error.no_template = No template found in '[_1]' key. This template is mandatory for the task to function.
action.error.param_required = Action parameter '[_1]' is empty but required for the task to function.
action.error.security = Security violation: you do not have rights to retrieve the requested object.
action.error.fetch = Cannot retrieve object: [_1]
action.error.create =  Object creation failed: [_1]
action.error.not_found = Object with ID '[_1]' not found
action.error.inactive = This object is currently inactive. Please check later.

action.error.fetch_for_update = Cannot fetch object for update: [_1]
action.error.update_not_saved = You cannot update this object because it has not yet been saved.
action.error.update_security = You do not have sufficient access to update this object. No modifications made.
action.error.update = Object update failed: [_1]
action.error.fetch_for_remove = Cannot fetch object for removal: [_1]
action.error.remove_not_saved = You cannot remove this object because it has not yet been saved.
action.error.remove_security = You do not have sufficient access to remove this object. \
    No modifications made.
action.error.remove = Object removal failed: [_1]
action.error.search_table_links = Misconfigured search: there should be either two or four \
    entries in the 'c_search_table_links' section for table '[_1]' under action '[_2]'.
action.error.search_too_many_results = Your search has returned too many results ([_1]). \
    Please try again.
action.status.create =  [_1] created properly.
action.status.update = [_1] updated with changes.
action.status.remove = [_1] successfully removed.