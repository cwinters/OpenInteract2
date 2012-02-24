base_security.assign.page_title = Edit Object Security
base_security.assign.title = Object Security
base_security.assign.summary = Edit the security for the object named below. \
    Note that you cannot currently mix and match security levels per \
    editing session -- for example, if you want to assign WRITE access to \
    Group A and 'READ' access to Group B, you need to first assign the rights \
    to Group A, click <tt>Go!</tt>, then come back to this screen and assign \
    the rights to Group B.
base_security.assign.label.class = Object Class: 
base_security.assign.label.id = Object ID: 
base_security.assign.label.type = Object Type: 
base_security.assign.visit_object = <a href="[_1]">Visit</a>
base_security.assign.label.user = User: 
base_security.assign.label.group = Group: 
base_security.assign.select_multiple = (you can select multiple items)
base_security.assign.label.access = Access
base_security.error.no_class.page_title = Error: No class for security editing
base_security.error.no_class.summary = Could not find an object class for which \
    I should modify security. No action taken.
base_security.error.unsecurable.title = Object Not Securable
base_security.error.unsecurable.title = This class ([_1]) is not currently a \
    subclass of the security implementation, meaning it is not under security \
    protection. You can edit the security and the entries will be put into \
    the security table, but they will not have any effect until you set \
    the key 'is_secure' to 'yes' in the configuration whether it's an \
    SPOPS object or an action.
base_security.error.fetch.title = Error: Failed to fetch security
base_security.hierarchy.page_title = Object Hierarchy Security
base_security.hierarchy.title = Security Hierarchy
base_security.hierarchy.summary = This object currently uses hierarchical security. \
    Listed here are the object and its parents.
base_security.hierarchy.label.id = Object ID
base_security.hierarchy.label.security = Security defined?
base_security.hierarchy.label.action = Action
base_security.hierarchy.label.is_defined = Defined
base_security.hierarchy.label.not_defined = Not defined
base_security.hierarchy.failure.title = Failure to Create Object!
base_security.hierarchy.failure.summary = For some reason, we were not able to \
    create an object to display the security. In theory, this should have been \
    caught earlier in the process and you should have seen a different error \
    message. Please contact the administrator.
base_security.list.page_title = Security Listing
base_security.list.title = Security Class Listing
base_security.list.summary = The following object and handler classes use \
    some sort of security. Choose one of them and, if necessary, enter an \
    object ID for which you want to edit the security.
base_security.list.class_option.header = <b>Object Classes</b><br> \
    The following are all object classes with security currently in the system.
base_security.list.class_option.first = SPOPS Object Classes
base_security.list.action_option.header = <b>Action Classes</b><br>
      The following are all action with security registered in the system.
base_security.list.action_option.first = Action Classes
base_security.list.button = Edit Security
base_security.error.failed_fetch = Cannot fetch security: [_1]
base_security.error.generic = Failed to [_1] security for [_2]: [_3]
base_security.error.remove = Removed security for [_1] scope [_2] ok
base_security.error.fetch_groups = Failed to fetch all security group scopes: [_1]
base_security.error.fetch_users = Failed to fetch all security user scopes: [_1]
base_security.status.generic = Successful [_1] security for [_2]