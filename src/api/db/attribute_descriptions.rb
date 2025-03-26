def update_all_attrib_type_descriptions
  ans = AttribNamespace.find_by_name('OBS')

  d = {
    'VeryImportantProject' => 'Mark this project as very important. For instance for the project list in the web interface.',
    'UpdateProject' => 'Mark this project as frozen, updates are handled via the project defined in the value.',
    'RejectRequests' => 'Request against this object get rejected. The first (optional) value will be given as reason to the requester. ' \
                        'Adding more values limits the rejection to the given request types (like "submit" or "delete").',
    'ApprovedRequestSource' => "Bypass the automatic request review when the request creator isn't the maintainer of this object.",
    'Maintained' => 'Marks this as object as maintained. For instance to find packages automatically when using the maintenance features like "osc mbranch".',
    'MaintenanceProject' => 'Mark this project as central maintenance project, which is used to coordinate all official updates.',
    'MaintenanceIdTemplate' => 'Released maintenance updates get an ID on first release. This attribute can be used to modify the default scheme.',
    #    "ScreenShots" => "", # to be dropped?
    'ImageTemplates' => 'Mark this project as source for image templates.',
    'OwnerRootProject' => 'Mark this project as starting point for the package ownership search. ' \
                          "Optional values: \"DisableDevel\": don't follow devel project links. \"BugownerOnly\": limit the result to bugowners (ignoring the maintainer role).",
    'RequestCloned' => 'Use this attribute to reference a request which will get superseded when a new submit request from this project gets created.',
    'ProjectStatusPackageFailComment' => 'Use this attribute to explain why this package is failing. This is displayed on the project status page for instance.',
    'InitializeDevelPackage' => 'Accepting a new package via a submit request to this project will set the devel project of the new package to the source of the request.',
    'BranchTarget' => 'Branches from this project will not follow any project links for the target link.',
    'BranchRepositoriesFromProject' => 'Use repository definitions from the specified project when creating a branch.',
    'BranchSkipRepositories' => 'Skip the listed repositories when branching from this project.',
    'AutoCleanup' => 'The object will recieve a delete request at specified time (YYYY-MM-DD HH:MM:SS) in the value',
    'Issues' => 'Use this attribute to reference issues this object has',
    'QualityCategory' => 'Use this attribute to classify the usability of a project. This gets used by the user package search for instance.',
    'IncidentPriority' => 'A numeric value which defines the importance of this incident project.',
    'EmbargoDate' => 'A timestamp until outgoing requests can not get accepted.',
    'PlannedReleaseDate' => 'A timestamp for the planned release date of an incident.',
    'MakeOriginOlder' => 'Initialize packages by making the build results newer then updated ones',
    'DelegateRequestTarget' => 'Delegate the target project of requests even when target_project is specified',
    'AllowSubmitToMaintenanceRelease' => 'Allow submit requests to maintenance release projects',
    'EnforceRevisionsInRequests' => 'Enforce revisions in request actions',
    'CreatorCannotAcceptOwnRequests' => 'The creator and the accepter of a request cannot be the same person',
    'SkipChannelBranch' => 'Opt-Out creating channels in maintenance incidents',
    'RejectBranch' => 'Reject branching of sources'
  }
  d.keys.each do |k|
    at = ans.attrib_types.where(name: k).first
    next unless at # might be called in older migrations

    at.description = d[k]
    at.save
  end
end
