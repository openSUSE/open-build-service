
def update_all_attrib_type_descriptions
  ans = AttribNamespace.find_by_name "OBS"
  
  d = { 
    "VeryImportantProject" => "Marks this project as top project for the project list in web interface",
    "UpdateProject" => "Marks this project as frozen, updates are handled via another project defined
  in the value",
    "RejectRequests" => "Request against this object get refused. The first optional value will be
given as reason to the user. When adding more values you can limit this rejection to the given action types
like \"submit\" or \"delete\"",
    "ApprovedRequestSource" => "Avoid becoming a reviewer, when creating submit requests from a source where no maintainer role is owned by request creator",
    "Maintained" => "Marks this as maintained package or project. Packages will be found automatically when
using the OBS maintenance features like \"osc mbranch\"",
    "MaintenanceProject" => "Marks the main maintenance project which is used to coordinate all official
updates by the maintenance team",
    "MaintenanceIdTemplate" => "Released maintenance updates get an ID on first release. This attribute can
be used to modify the default scheme",
#    "ScreenShots" => "", # to be dropped? 
    "OwnerRootProject" => "Justifies the behaviour of package owner ship. DisableDevel will disable the lookup in devel projects. BugownerOnly will limit the result to bugowners and will ignore maintainer roles.",
    "RequestCloned" => "A marker inside of a project to reference a clone request. The request will get
superseded when a new submit request from this project gets created.",
    "ProjectStatusPackageFailComment" => "Can be used to store reasons to be shown on failing packages of a project status page in webui.",
    "InitializeDevelPackage" => "The request source will become a devel package, when creating a new package by submit request",
    "BranchTarget" => "Branches do by default always point to the package origin even when branched from another project and the source got found via project links. This attribute in a project linking to others will
enforce to become the package link target.",
    "BranchRepositoriesFromProject" => "Use repository definitions from another specified project when creating a branch",
    "AutoCleanup" => "The object will recieve a delete request at specified time in the value",
    "Issues" => "To reference issues without touching the source",
    "QualityCategory" => "To classify the usability of a project. The end user search will take care and priorize according to this attribute.",
  }
  
  for k in d.keys do
    at = ans.attrib_types.where(name: k).first
    at.description = d[k]
    at.save
  end
end

