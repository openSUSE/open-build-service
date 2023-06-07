# OpenAPI Specification for the Open Build Service HTTP API

This is the API specification for the Open Build Service HTTP API.

You can look at this online for the reference server at

https://api.opensuse.org/apidocs/

or at the same location (`/apidocs/`) in your local OBS installation.

We are using the [OpenAPI Specification (OAS) version 3.0.0](https://spec.openapis.org/oas/v3.0.0)
to document the API and the [Swagger UI](https://swagger.io/tools/swagger-ui/) tool to display
it.

## How to contribute?

Are you missing documentation for an endpoint? Did you find errors or oversights
in the current documentation? Check out the [OpenAPI Guide](https://swagger.io/docs/specification/about/), our [OBS contribution guide](https://github.com/openSUSE/open-build-service/blob/master/CONTRIBUTING.md) and contribute fixes, please!

- Endpoints are declared in OBS-v2.10.50.yaml (please keep them in alphabetical order)
- Endpoint docu is defined in the paths/ directory
- Endpoint docu can make use of the components (parameters, responses, schemas) in the components/ directory

You can also have a look at [closed pull requests](https://github.com/openSUSE/open-build-service/pulls?q=is%3Apr+label%3A%22Documentation+%3Abook%3A%22+is%3Aclosed) to take what others did before as an example.

